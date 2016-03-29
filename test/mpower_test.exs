defmodule MpowerTest do
  use ExUnit.Case
  alias MPower.{Client, Invoice, Store}
  doctest MPower

  test "defualt mode is sandbox mode" do
    assert Client.process_url("foo") == "https://app.mpowerpayments.com/sandbox-api/v1/foo"
  end

  test "add custom data" do
    invoice =
      %Invoice{}
      |> Invoice.add_meta(%{location: %{lat: 12, lon: 45}})

    assert invoice.custom_data == %{location: %{lat: 12, lon: 45}}
  end

  test "add actions to invoice" do
    invoice =
      %Invoice{}
      |> Invoice.add_action(%{cancel_url: "/foo/bar"})

    assert invoice.actions[:cancel_url] == "/foo/bar"
  end

  test "add invoice items" do
    items = Enum.map(0..3, fn _ -> %Invoice.Item{} end)
    invoice = %Invoice{}

    invoice =
      invoice
      |> Invoice.add_items(items)
      |> Invoice.add_items(items)
      |> Invoice.add_items(items)

    assert length(invoice.items) == 12
  end

  test "create invoice" do
    items = Enum.map(0..3, fn _ -> %Invoice.Item{} end)
    store = %Store{name: "Hello Hello"}
    invoice = %Invoice{description: "3 books", total_amount: 20}

    response =
      (invoice
      |> Invoice.add_items(items)
      |> Invoice.add_taxes([%Invoice.Tax{name: "Ghana Post tax", amount: 3}])
      |> Invoice.add_action(%{"return_url" => "http://localhost:400/checkout"})
      |> Invoice.create(store))

    token = response.data["token"]
    created? = (response.response_code == "00"
                && String.starts_with?(token, "test_"))
    assert created?
  end
end
