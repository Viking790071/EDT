
#Region ServiceProceduresAndFunctions

Procedure ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, Owner) Export
	
	If Find(DataLoadSettings.DataImportFormNameFromExternalSources, "DataImportFromExternalSources") > 0 Then
		
		DataImportingParameters = New Structure("DataLoadSettings", DataLoadSettings);
		
	EndIf;
	
	DataImportingParameters_AddCounterparty(DataLoadSettings, Owner);
	
	OpenForm(DataLoadSettings.DataImportFormNameFromExternalSources, DataImportingParameters, Owner, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

Procedure DataImportingParameters_AddCounterparty(DataLoadSettings, Owner)
	
	If Not DataLoadSettings.Property("TabularSectionFullName")
		OR NOT(DataLoadSettings.TabularSectionFullName = "PurchaseOrder.Inventory"
			OR DataLoadSettings.TabularSectionFullName = "GoodsReceipt.Products"
			OR DataLoadSettings.TabularSectionFullName = "SupplierInvoice.Inventory") Then
		Return;
	EndIf;
	
	DataLoadSettings.Insert("Supplier", Owner.Object.Counterparty);
	
EndProcedure

Function GetAccountingEntriesSettings(Form, CurrentTableName, Cancel) Export
	
	Object = Form.Object;
	
	RequiredAttributes = New Map;
	RequiredAttributes.Insert("Date", NStr("en = 'Date'; ru = 'Дата';pl = 'Data';es_ES = 'Fecha';es_CO = 'Fecha';tr = 'Tarih';it = 'Data';de = 'Datum'"));
	RequiredAttributes.Insert("Company", NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	RequiredAttributes.Insert("TypeOfAccounting", NStr("en = 'Type of accounting'; ru = 'Тип бухгалтерского учета';pl = 'Typ rachunkowości';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe türü';it = 'Tipo di contabilità';de = 'Typ der Buchhaltung'"));
	
	ExcludedAttributes = New Array;
	
	For Each Attribute In RequiredAttributes Do
		
		AttributeName = Attribute.Key;
		
		If Not CommonClientServer.HasAttributeOrObjectProperty(Object, AttributeName) Then
			
			ExcludedAttributes.Add(AttributeName);
			Continue;
			
		EndIf;
		
		If Not ValueIsFilled(Object[AttributeName]) Then
			
			Cancel = True;
			MessageText = StrTemplate(NStr("en = 'The ""%1"" field is required'; ru = 'Поле ""%1"" не заполнено';pl = 'Pole ""%1"" jest wymagane';es_ES = 'El ""%1"" es obligatorio.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı zorunlu';it = 'Il campo ""%1"" è richiesto';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), Attribute.Value);
			
			CommonClientServer.MessageToUser(MessageText, , AttributeName, "Object");
			
		EndIf;
		
	EndDo;
	
	For Each Attribute In ExcludedAttributes Do
		RequiredAttributes.Delete(Attribute);
	EndDo;
	
	Result = New Structure;
	
	For Each Attribute In RequiredAttributes Do
		
		AttributeName = Attribute.Key;
		Result.Insert(AttributeName, Object[AttributeName]);
		
	EndDo;
	
	ChartOfAccountsData = DataImportFromExternalSources.GetChartOfAccountsData(Object.ChartOfAccounts);
	
	Result.Insert("ChartOfAccounts", Object.ChartOfAccounts);
	Result.Insert("UseQuantity", ChartOfAccountsData.UseQuantity);
	Result.Insert("TypeOfEntries", ChartOfAccountsData.TypeOfEntries);
	Result.Insert("UseAnalyticalDimensions", ChartOfAccountsData.UseAnalyticalDimensions);
	Result.Insert("MaxAnalyticalDimensionsNumber", WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber());
	
	If Result.TypeOfEntries = PredefinedValue("Enum.ChartsOfAccountsTypesOfEntries.Compound") Then
		
		MaxEntryNumber = 0;
		For Each Row In Form[CurrentTableName] Do
			MaxEntryNumber = Max(Row.EntryNumber, MaxEntryNumber);
		EndDo;
		
		Result.Insert("MaxEntryNumber", MaxEntryNumber + 1);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
