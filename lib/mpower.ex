defmodule MPower do
  defmodule Response do
    @moduledoc """
    MPower API response struct.

    Every response contains `response_code` and `response_text`. Some response
    may contain other data which is contextualy relevant to the request made. For
    such data, we put them in the `data` field.
    """
    defstruct [:response_code, :response_text, :data, :success]
  end

  defmodule Error do
    defexception [:message]
  end
end

defmodule MPower.Client do
  @moduledoc "HTTP client for communicating with the MPower API"
  use HTTPoison.Base
  require Logger

  #Sandbox Endpoint
  @sandbox_server "https://app.mpowerpayments.com/sandbox-api/v1/"

  #Live Endpoint
  @live_server "https://app.mpowerpayments.com/api/v1/"

  @user_agent "MPower Elixir v0.1.0"

  defp get_config(key, default) do
    Application.get_env(:mpower, key, default)
  end

  defp fetch_config(key) do
    case get_config(key, :not_found) do
      :not_found ->
        raise ArgumentError, "the configuration parameter #{inspect(key)} is not set"
      value -> value
    end
  end

  def process_url(url) do
    case get_config(:mode, :test) do
      :live ->
        @live_server <> url
      mode when mode in [nil, :test] ->
        @sandbox_server <> url
      _ ->
        raise ArgumentError, """
          the configuration parameter `mode` must be either :test or
          :live. Defaults to :test
        """
    end
  end

  def get(url) do
    super(url)
    |> handle_response
  end

  def post(url, body) do
    body = Poison.encode!(body)
    super(url, body)
    |> handle_response
  end

  defp handle_response(response) do
    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("MPower request successful")
        body = Poison.decode!(body)
        response_code = body["response_code"]
        response_text = body["response_text"]
        if response_code == "00" do
          other_data = Map.drop(body, ["response_text", "response_code"])
          %MPower.Response{
                     success: true,
                     response_code: response_code,
                     response_text: response_text,
                     data: other_data
                 }
        else
          %MPower.Response{
                     success: false,
                     response_code: response_code,
                     response_text: response_text,
                 }
        end
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        Logger.info "404. Path Not found :("
        {:error, 404}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error reason
        {:error, reason}
    end
  end

  def process_request_headers(headers) do
    mpower_headers = [
      {"MP-Master-Key", fetch_config(:master_key)},
      {"MP-Private-Key", fetch_config(:private_key)},
      {"MP-Token", fetch_config(:token)}
    ]
    headers ++ mpower_headers
  end
end


defmodule MPower.Invoice do
  defstruct [
    :total_amount,
    :description,
    :items,
    :taxes,
    :custom_data,
    :actions
  ]

  defmodule Item do
    defstruct [
      :name,
      :quantity,
      :unit_price,
      :total_price,
      :description
    ]
  end

  defmodule Tax do
    defstruct [:name, :amount]
  end

  def create(invoice, store) do
    body = build(invoice, store)
    MPower.Client.post("checkout-invoice/create", body)
  end

  def build(invoice, store) do
    meta = Map.take(invoice, [:custom_data, :actions])
    invoice = Map.drop(invoice, [:custom_data, :actions])
    %{"invoice" => invoice, "store" => store}
    |> Map.merge(meta)
  end

  def check_status(token) do
    MPower.Client.get("checkout-invoice/confirm/#{token}")
  end

  def add_items(invoice, new_items) when is_list(new_items) do
    case invoice.items do
      nil ->
        %{invoice | items: itemize(new_items)}
      items ->
        old_items =
          items
          |> Enum.map(fn {k,v} -> v end)
          |> List.flatten

        items = old_items ++ new_items
        %{invoice | items: itemize(items)}
    end
  end

  def itemize(items, prefix \\ "item_") do
    {xs, _acc} =
      Enum.map_reduce(items, 0, fn(x, acc) ->
        {{"#{prefix}#{acc}", x}, acc+1}
      end)

    xs |> Map.new
  end

  def add_taxes(invoice, new_taxes) when is_list(new_taxes) do
    case invoice.taxes do
      nil ->
        %{invoice | taxes: itemize(new_taxes, "tax_")}
      taxes ->
        old_taxes =
        taxes
        |> Enum.map(fn {k, v} -> v end)
        |> List.flatten

        taxes = old_taxes ++ new_taxes
        %{invoice | taxes: itemize(taxes, "tax_")}
    end
  end

  def add_meta(invoice, metadata) do
    case invoice.custom_data do
      nil ->
        %{invoice | custom_data: metadata}
      custom_data ->
        %{invoice | custom_data: Map.merge(custom_data, metadata)}
    end
  end

  def add_action(invoice, action_kv) do
    case invoice.actions do
      nil ->
        %{invoice | actions: action_kv}
      actions ->
        %{invoice | actions: Map.merge(actions, action_kv)}
    end
  end
end


defmodule MPower.Store do
  defstruct [
    :name,
    :tagline,
    :postal_address,
    :phone,
    :website_url,
    :logo_url
  ]
end


defmodule MPower.OPR do
  defstruct [:store, :invoice, :opr_data]

  defmodule Data do
    defstruct [:account_alias]
  end

  def create(invoice, store, account_alias) do
    body = build(invoice, store, account_alias)
    MPower.Client.post("opr/create", body)
  end

  def build(invoice, store, account_alias) do
    opr = %Data{account_alias: account_alias}
    %{"invoice_data" => %__MODULE__{invoice: invoice, store: store,
                                    opr_data: opr}}
  end

  def confirm(opr_token, confirm_token) do
    body = %{token: opr_token, confirm_token: confirm_token}
    MPower.Client.post("opr/charge", body)
  end
end

defmodule MPower.DirectPay do
  defstruct [:account_alias, :amount]

  def credit_account(account_alias, amount) do
    body = %__MODULE__{account_alias: account_alias, amount: amount}
    MPower.Client.post("direct-pay/credi-account", body)
  end
end

defmodule MPower.DirectMobile do
  defstruct [
    :customer_name,
    :customer_phone,
    :customer_email,
    :wallet_provider,
    :merchant_name,
    :amount
  ]

  def charge(data) do
    if Application.get_env(:mpower, :mode) != :live do
      raise MPower.Error, "Direct Mobile operations only allowed in live mode"
    end
    MPower.Client.post("direct-mobile/charge", data)
  end

  def check_status(token) do
    if Application.get_env(:mpower, :mode) != :live do
      raise MPower.Error, "Direct Mobile operations only allowed in live mode"
    end
    MPower.Client.post("direct-mobile/status", %{"token" => token})
  end
end
