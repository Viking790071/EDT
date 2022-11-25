#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function ProductBatchSettings(Product) Export
	
	Result = New Structure;
	Result.Insert("UseBatchNumber", False);
	Result.Insert("UseExpirationDate", False);
	Result.Insert("ExpirationDatePrecision", Enums.DatePrecision.EmptyRef());
	Result.Insert("UseProductionDate", False);
	Result.Insert("ProductionDatePrecision", Enums.DatePrecision.EmptyRef());
	Result.Insert("DescriptionTemplate", "");
	Result.Insert("DefaultTrackingPolicy", Catalogs.BatchTrackingPolicies.EmptyRef());
	
	Query = New Query;
	
	Query.SetParameter("Product", Product);
	
	Query.Text =
	"SELECT
	|	Products.ProductsCategory AS ProductsCategory
	|INTO TT_ProductCategory
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.Ref = &Product
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogBatchSettings.UseBatchNumber AS UseBatchNumber,
	|	CatalogBatchSettings.UseExpirationDate AS UseExpirationDate,
	|	CatalogBatchSettings.ExpirationDatePrecision AS ExpirationDatePrecision,
	|	CatalogBatchSettings.UseProductionDate AS UseProductionDate,
	|	CatalogBatchSettings.ProductionDatePrecision AS ProductionDatePrecision,
	|	CatalogBatchSettings.DescriptionTemplate AS DescriptionTemplate,
	|	CatalogBatchSettings.DefaultTrackingPolicy AS DefaultTrackingPolicy
	|FROM
	|	TT_ProductCategory AS TT_ProductCategory
	|		INNER JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON TT_ProductCategory.ProductsCategory = ProductsCategories.Ref
	|		INNER JOIN Catalog.BatchSettings AS CatalogBatchSettings
	|		ON (ProductsCategories.BatchSettings = CatalogBatchSettings.Ref)";
	
	Sel = Query.Execute().Select();
	If Sel.Next() Then
		FillPropertyValues(Result, Sel);
	EndIf;
	
	Return Result;
	
EndFunction

#Region LibrariesHandlers

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectAttributesLockOverridable.OnDefineObjectsWithLockedAttributes.
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("UseBatchNumber");
	AttributesToLock.Add("UseExpirationDate");
	AttributesToLock.Add("ExpirationDatePrecision");
	AttributesToLock.Add("UseProductionDate");
	AttributesToLock.Add("ProductionDatePrecision");
	AttributesToLock.Add("DefaultTrackingPolicy");
	AttributesToLock.Add("TrackingPolicy");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(ChoiceData,
		Parameters, StandardProcessing, Metadata.Catalogs.BatchSettings);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf