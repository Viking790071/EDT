#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region CloneProductRelatedData

Procedure MakeRelatedReorderPointSettings(ProductReceiver, ProductSource, FillProductVariants) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReorderPointSettings.Company AS Company,
	|	ReorderPointSettings.Products AS Products,
	|	ReorderPointSettings.Characteristic AS Characteristic,
	|	ReorderPointSettings.Characteristic.Description AS CharacteristicDescription,
	|	ReorderPointSettings.InventoryMinimumLevel AS InventoryMinimumLevel,
	|	ReorderPointSettings.InventoryMaximumLevel AS InventoryMaximumLevel,
	|	CASE
	|		WHEN NOT ReorderPointSettings.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				AND VALUETYPE(ReorderPointSettings.Characteristic.Owner) = TYPE(Catalog.Products)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FillCharacteristics
	|FROM
	|	InformationRegister.ReorderPointSettings AS ReorderPointSettings
	|WHERE
	|	ReorderPointSettings.Products = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	NewRecords = InformationRegisters.ReorderPointSettings.CreateRecordSet();
	NewRecords.Filter.Products.Set(ProductReceiver);
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.FillCharacteristics And Not FillProductVariants Then
			Continue;
		EndIf;
		
		If SelectionDetailRecords.FillCharacteristics And FillProductVariants Then
			CharacteristicReceiver = Catalogs.ProductsCharacteristics.FindByDescription(SelectionDetailRecords.CharacteristicDescription,,,ProductReceiver);
		Else 
			CharacteristicReceiver = Catalogs.ProductsCharacteristics.EmptyRef();
		EndIf;
		
		NewRecord = NewRecords.Add();
		FillPropertyValues(NewRecord, SelectionDetailRecords,,"Products, Characteristic");
		NewRecord.Products = ProductReceiver;
		NewRecord.Characteristic = CharacteristicReceiver;
		NewRecords.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf