#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region CloneProductRelatedData

Procedure MakeRelatedSubstituteGoods(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SubstituteGoods.Products AS Products,
		|	SubstituteGoods.Analog AS Analog,
		|	SubstituteGoods.Priority AS Priority,
		|	SubstituteGoods.Comment AS Comment
		|FROM
		|	InformationRegister.SubstituteGoods AS SubstituteGoods
		|WHERE
		|	SubstituteGoods.Products = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	NewRecords = InformationRegisters.SubstituteGoods.CreateRecordSet();
	NewRecords.Filter.Products.Set(ProductReceiver);
	
	While SelectionDetailRecords.Next() Do
		NewRecord = NewRecords.Add();
		FillPropertyValues(NewRecord, SelectionDetailRecords,,"Products");
		NewRecord.Products = ProductReceiver;
		NewRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf