defmodule MpowerTest do
  use ExUnit.Case
  alias MPower.{Client, Invoice, Store, DirectMobile}
  doctest MPower

  @test_invoice %MPower.Invoice{actions: nil, custom_data: nil, description: nil, items:
                                %{"item_0" => %MPower.Invoice.Item{description: nil, name: nil,    quantity:
                                                                   nil, total_price: nil, unit_price: nil},   "item_1" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_10" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_11" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_2" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_3" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_4" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_5" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_6" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_7" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_8" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil},   "item_9" =>
                                   %MPower.Invoice.Item{description: nil, name: nil, quantity: nil,
                                                        total_price: nil, unit_price: nil}}, taxes: nil, total_amount: nil}


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
      (invoice
      |> Invoice.add_items(items)
      |> Invoice.add_items(items)
      |> Invoice.add_items(items))

    assert invoice == @test_invoice
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

    assert (response.success && Map.has_key?(response.data, "token"))
  end

  test "direct mobile charge only happens in live mode" do
    dm = %DirectMobile{
                 customer_name: "Ama",
                 customer_phone: "0124223311",
                 wallet_provider: "Airtel",
                 amount: 2,
                 merchant_name: "MPower Elixir Shop",
             }
    assert_raise MPower.Error, fn ->
      DirectMobile.charge(dm)
    end
  end
end
