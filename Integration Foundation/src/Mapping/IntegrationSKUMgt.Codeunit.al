codeunit 73298425 "Integration SKU Mgt."
{
    // The data-access seam for SKU mappings. Handlers and outbound events resolve
    // SKUs through here, never by reading the mapping table directly. The lookups are
    // stateless reads with no side effects, so they are safe to call on a hot path.

    /// <summary>
    /// Forward lookup. Returns true and loads the mapping (item, variant, unit of
    /// measure) when the SKU is mapped, false otherwise. The caller decides how to
    /// fail a miss; an inbound handler should raise a permanent error so the message
    /// goes to manual resolution rather than retrying forever.
    /// </summary>
    procedure TryGetMapping(SKU: Code[20]; var SKUMapping: Record "Integration SKU Mapping"): Boolean
    begin
        exit(SKUMapping.Get(SKU));
    end;

    /// <summary>
    /// Forward lookup that raises a clear error naming the unmapped SKU. For callers
    /// outside the integration dispatch path that want a hard stop rather than a
    /// classified failure.
    /// </summary>
    procedure GetMapping(SKU: Code[20]; var SKUMapping: Record "Integration SKU Mapping")
    var
        NotMappedErr: Label 'SKU ''%1'' is not mapped to a Business Central item. Add it in Integration SKU Mappings.', Comment = '%1 = the unmapped SKU';
    begin
        if not SKUMapping.Get(SKU) then
            Error(NotMappedErr, SKU);
    end;

    /// <summary>
    /// Reverse lookup (item to SKU) for outbound payloads that must carry the source
    /// system's own catalogue key. Returns the first SKU mapped to the item/variant.
    /// </summary>
    procedure TryGetSKU(ItemNo: Code[20]; VariantCode: Code[10]; var SKU: Code[20]): Boolean
    var
        SKUMapping: Record "Integration SKU Mapping";
    begin
        SKUMapping.SetCurrentKey("Item No.", "Variant Code");
        SKUMapping.SetRange("Item No.", ItemNo);
        SKUMapping.SetRange("Variant Code", VariantCode);
        if SKUMapping.FindFirst() then begin
            SKU := SKUMapping.SKU;
            exit(true);
        end;
        exit(false);
    end;
}
