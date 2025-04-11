codeunit 50350 TransferOrderCodeunit
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateLocationCode, '', false, false)]
    local procedure doTranferAfterTakingLocationCode(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line")
    var
        item: Record Item;
        locations: Record Location;
    begin
        if (SalesLine.Quantity = 0) or (SalesLine."Location Code" = xSalesLine."Location Code") then
            exit;

        if SalesLine.Type <> SalesLine.Type::Item then exit;
        locations.Get(SalesLine."Location Code");
        if ((locations."Require Receive" = true) or (locations."Require Shipment" = true) or (locations."Require Put-away" = true) or (locations."Require Pick" = true) or (locations."Directed Put-away and Pick" = true)) then
            exit;

        if not item.Get(SalesLine."No.") then
            exit;
        item.SetFilter("Location Filter", '%1', SalesLine."Location Code");
        item.CalcFields(Inventory);
        checkAvailabilityOfQuantityAndCallFunctionForTransferOrderIfNotExists(SalesLine, item, locations);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterInitOutstandingQty, '', false, false)]
    local procedure doTransferAfterTakingQuantity(var SalesLine: Record "Sales Line")
    var
        item: Record Item;


        locations: Record Location;
        transferHeader: Record "Transfer Header";
        transferLine: Record "Transfer Line";
    begin
        if (SalesLine."Location Code" = '') or (SalesLine.Quantity = 0) then
            exit;
        if SalesLine.Type <> SalesLine.Type::Item then exit;
        locations.Get(SalesLine."Location Code");
        if ((locations."Require Receive" = true) or (locations."Require Shipment" = true) or (locations."Require Put-away" = true) or (locations."Require Pick" = true) or (locations."Directed Put-away and Pick" = true)) then
            exit;

        if not item.Get(SalesLine."No.") then
            exit;
        item.SetFilter("Location Filter", '%1', SalesLine."Location Code");
        item.CalcFields(Inventory);
        checkAvailabilityOfQuantityAndCallFunctionForTransferOrderIfNotExists(SalesLine, item, locations);
    end;

    local procedure checkAvailabilityOfQuantityAndCallFunctionForTransferOrderIfNotExists(var SalesLine: Record "Sales Line"; var item: Record Item; var locations: Record Location)
    var
        item1: Record Item; //To Check The Item At Every Location
        quantityToTransfer: Decimal;
    begin
        Message('Items avaialble in %1 is %2', SalesLine."Location Code", item.Inventory);
        if SalesLine.Quantity > item.Inventory then begin
            quantityToTransfer := SalesLine.Quantity - item.Inventory;
            locations.Reset();
            locations.FindSet();
            repeat
                if (not ((locations."Require Receive" = true) or (locations."Require Shipment" = true) or (locations."Require Put-away" = true) or (locations."Require Pick" = true))) and (not (locations."Directed Put-away and Pick" = true)) and (SalesLine."Location Code" <> locations.Code) and (locations.Code <> '') then begin
                    // Message('Location Code: %1', locations.Code);
                    item1.Get(SalesLine."No.");
                    item1.SetFilter("Location Filter", '%1', locations.Code);
                    item1.CalcFields(Inventory);
                    // Message('Items in inventory %1 is %2', locations.Code, item1.Inventory);
                    // Message('Quantity to transfer is : %1', quantityToTransfer);
                    if item1.Inventory >= quantityToTransfer then begin
                        // Message('Control came to if');
                        transferQuantityByPostingTransferOrder(SalesLine, locations.Code, quantityToTransfer);
                        quantityToTransfer := 0;
                        break;
                    end
                    else begin
                        if item1.Inventory > 0 then begin
                            // Message('Control came to else');
                            quantityToTransfer -= item1.Inventory;
                            // Message('Quantity to Transfer: ', quantityToTransfer);
                            transferQuantityByPostingTransferOrder(SalesLine, locations.Code, item1.Inventory);
                        end;
                    end;
                end;
            until locations.Next() = 0;

            if quantityToTransfer <> 0 then begin
                SalesLine.Validate(Quantity, SalesLine.Quantity - quantityToTransfer);
                Message('We can not ship %1 quantity due to out of stock.', quantityToTransfer);
            end;
        end;
    end;

    local procedure transferQuantityByPostingTransferOrder(var SalesLine: Record "Sales Line"; locationCode: Code[10]; quantityToTransfer: Decimal)
    var
        transferHeader: Record "Transfer Header";
        transferLine: Record "Transfer Line";
        salesHeader: Record "Sales Header";
    begin
        // Message('Location Code Of Function : ', locationCode);
        // Message('Quantity To Transfer of Function: ', quantityToTransfer);
        // Message('Control Came to Function');
        salesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        transferHeader.Init();
        transferHeader.Insert(true);
        transferHeader.Validate("Direct Transfer", true);
        transferHeader.Validate("Transfer-from Code", locationCode);
        transferHeader.Validate("Transfer-to Code", SalesLine."Location Code");
        transferHeader.Validate("Posting Date", salesHeader."Posting Date");
        transferHeader.Validate("Shipment Date", salesHeader."Shipment Date");
        transferHeader.Validate("Receipt Date", Today);
        transferHeader.Validate("Shipping Advice", transferHeader."Shipping Advice"::Partial);
        transferHeader.Modify();
        // Message('Transfer From Code %1', transferHeader."Transfer-from Code");
        // Message('Transfer To Code %1', transferHeader."Transfer-to Code");

        transferLine.Init();
        transferLine.Validate("Document No.", transferHeader."No.");
        transferLine.Validate("Line No.", 10000);
        transferLine.Validate("Item No.", SalesLine."No.");
        transferLine.Validate(Description, SalesLine.Description);
        transferLine.Validate(Quantity, quantityToTransfer);
        transferLine.Validate("Unit of Measure Code", SalesLine."Unit of Measure Code");
        transferLine.Validate("Qty. to Ship", quantityToTransfer);
        transferLine.Validate("Qty. to Receive", quantityToTransfer);
        transferLine.Validate("Shipment Date", salesHeader."Shipment Date");
        transferLine.Validate("Receipt Date", Today);
        // Message('Quantity to Transfer: ', quantityToTransfer);
        // Message('Quantity: ', transferLine.Quantity);
        // Message('Quantity to ship: ', transferLine."Qty. to Ship");
        // Message('Quantity to receive: ', transferLine."Qty. to Receive");
        transferLine.Insert();

        CODEUNIT.Run(CODEUNIT::"TransferOrder-Post (Yes/No)", transferHeader);
        // Message('Quantity transfered');
    end;
}