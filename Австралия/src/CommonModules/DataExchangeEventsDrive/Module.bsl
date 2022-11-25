#Region Public

#Region ExportImportDataInService

// Procedure-processor of the BeforeObjectImport for the data
// export/import mechanism in the Parameters description service see commentary to DataExportImportOverridable.OnDataImportHandlersRegistration
// 
Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	// Disable registration of counterparties duplicates on data load/export in service
	If TypeOf(Object) = Type("CatalogObject.Counterparties") Then
		Object.AdditionalProperties.Insert("RegisterCounterpartiesDuplicates", False);
	ElsIf TypeOf(Object) = Type("CatalogObject.AutomaticDiscountTypes") Then
		Object.AdditionalProperties.Insert("RegisterServiceAutomaticDiscounts", False);
	EndIf; 
	
EndProcedure

#EndRegion

#Region FullDataExchange

Procedure DataExchangeFullBeforeWriteDocument(Source, Cancel, WriteMode, PostingMode) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteDocument("Full", Source, Cancel, WriteMode, PostingMode);
	EndIf;
	
EndProcedure

Procedure DataExchangeFullBeforeWrite(Source, Cancel) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeWrite("Full", Source, Cancel);
	EndIf;
	
EndProcedure

Procedure DataExchangeFullBeforeWriteRegister(Source, Cancel, Overwrite) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteRegister("Full", Source, Cancel, Overwrite);
	EndIf;
	
EndProcedure

Procedure DataExchangeFullBeforeWriteConstant(Source, Cancel) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeWriteConstant("Full", Source, Cancel);
	EndIf;
	
EndProcedure

Procedure DataExchangeFullBeforeDelete(Source, Cancel) Export
	
	If Not CommonCached.DataSeparationEnabled() Then
		DataExchangeEvents.ObjectsRegistrationMechanismBeforeDelete("Full", Source, Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
