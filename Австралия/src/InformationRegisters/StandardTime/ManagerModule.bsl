#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region CloneProductRelatedData

Procedure MakeRelatedStandardTime(ProductReceiver, ProductSource, FillProductVariants) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	StandardTime.Period AS Period,
	|	StandardTime.Products AS Products,
	|	StandardTime.Characteristic AS Characteristic,
	|	StandardTime.Characteristic.Description AS CharacteristicDescription,
	|	StandardTime.Norm AS Norm,
	|	CASE
	|		WHEN NOT StandardTime.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				AND VALUETYPE(StandardTime.Characteristic.Owner) = TYPE(Catalog.Products)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FillCharacteristics
	|FROM
	|	InformationRegister.StandardTime AS StandardTime
	|WHERE
	|	StandardTime.Products = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	NewRecords = InformationRegisters.StandardTime.CreateRecordSet();
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