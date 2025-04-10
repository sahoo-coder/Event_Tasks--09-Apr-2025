codeunit 50350 TransferOrderCodeunit
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateLocationCode, '', false, false)]
    local procedure doTranferAfterTakingLocationCode(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line")
    begin
        if (SalesLine.Quantity = 0) or (SalesLine."Location Code" = xSalesLine."Location Code") then
            exit;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterInitOutstandingQty, '', false, false)]
    local procedure doTransferAfterTakingQuantity(var SalesLine: Record "Sales Line")
    var
        item: Record Item;
        item1: Record Item;
        quantityToTransfer: Integer;
        locations: Record Location;
        isQuantityadjusted: Boolean;
    begin
        if (SalesLine."Location Code" = '') or (SalesLine.Quantity = 0) then
            exit;

        Item.Get(SalesLine."No.");
        item.SetFilter("Location Filter", '%1', SalesLine."Location Code");
        item.CalcFields(Inventory);
        if SalesLine.Quantity > item.Inventory then begin
            quantityToTransfer := SalesLine.Quantity - item.Inventory;
            repeat
                item1.Get(SalesLine."No.");
                item1.SetFilter("Location Filter", '%1', locations.Code);
                item1.CalcFields(Inventory);
                if item1.Inventory
            until locations.Next() = 0;
        end;
        end;

    // Item.Get(SalesLine."No.");
    //     item.SetFilter("Location Filter", '%1', SalesLine."Location Code");
    //     item.CalcFields(Inventory);
}