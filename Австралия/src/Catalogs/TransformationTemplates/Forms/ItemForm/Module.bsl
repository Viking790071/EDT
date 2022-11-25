
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillChoiseLists();
	FillReceivingResourceChoiceList();
	
	CopyingObject = Parameters.CopyingValue;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CopyingMappingSettings(Cancel, CurrentObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SourceChartOfAccountsOnChange(Item)
	
	ChartOfAccountsOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ReceivingChartOfAccountsOnChange(Item)
	
	ChartOfAccountsOnChangeAtServer(True);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure MappingSettings(Command)
	
	If Parameters.Key.IsEmpty() Or Modified Then
		
		ShowQueryBox(
			New NotifyDescription("MappingSettingsEnd", ThisObject),
			NStr("en = 'The translation template is not saved. Do you want to save the template?'; ru = 'Шаблон преобразования не сохранен. Сохранить?';pl = 'Szablon tłumaczenia nie jest zapisany. Czy chcesz zapisać szablon?';es_ES = 'La plantilla de traducción no se guarda. ¿Quiere guardar la plantilla?';es_CO = 'La plantilla de traducción no se guarda. ¿Quiere guardar la plantilla?';tr = 'Çeviri şablonu kaydedilmemiş. Şablonu kaydetmek istiyor musunuz?';it = 'Il modello di traduzione non è salvato. Salvare il modello?';de = 'Die Übersetzungsvorlage ist nicht gespeichert. Möchten Sie die Vorlage speichern?'"),
			QuestionDialogMode.YesNo);
			
		Return;
		
	EndIf;
		
	OpenForm(
		"DataProcessor.MappingSettings.Form",
		New Structure("TransformationTemplate", Object.Ref));
		
EndProcedure

&AtClient
Procedure MappingSettingsEnd(Result, AdditionalParameters) Export
	
	OpenIsAllowed = True;
	If Result = DialogReturnCode.Yes Then
		Try
			Write();
		Except
			
			MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Errors occurred while writing the %1  translation template: %2'; ru = 'Во время записи шаблона преобразования %1 произошли ошибки: %2.';pl = 'Wystąpiły błędy podczas zapisywania %1  szablonu tłumaczenia: %2';es_ES = 'Se han producido errores al escribir la %1  plantilla de traducción: %2';es_CO = 'Se han producido errores al escribir la %1  plantilla de traducción: %2';tr = '%1 çeviri şablonu yazılırken hatalar oluştu:%2';it = 'Si sono verificati degli errori durante la scrittura del %1 modello di traduzione: %2';de = 'Ein Fehler ist beim Schreiben der Übersetzungsvorlage %1 aufgetreten: %2'"),
				String(Object.Ref),
				ErrorDescription());
			
			CommonClientServer.MessageToUser(MessageToUser);
			OpenIsAllowed = False;
		EndTry;
	ElsIf Result = DialogReturnCode.No Then
		Return;
	Else
		MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Unknown option is selected: %1'; ru = 'Выбрана неизвестная опция: %1';pl = 'Wybrano nie znaną opcje: %1';es_ES = 'La opción desconocida está seleccionada: %1';es_CO = 'La opción desconocida está seleccionada: %1';tr = 'Bilinmeyen seçenek seçili:%1';it = 'Selezionata opzione sconosciuta: %1';de = 'Eine unbekannte Option ist ausgewählt: %1'"),
				String(Result));
			
		CommonClientServer.MessageToUser(MessageToUser);
	EndIf;
	
	If OpenIsAllowed And (ValueIsFilled(Object.Ref)) Then
		
		OpenForm(
			"DataProcessor.MappingSettings.Form",
			New Structure("TransformationTemplate", Object.Ref));
			
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'Mapping operation canceled.'; ru = 'Операция сопоставления отменена.';pl = 'Anulowano operacje mapowania';es_ES = 'Operación de mapeo cancelada.';es_CO = 'Operación de mapeo cancelada.';tr = 'Eşleme işlemi iptal edildi.';it = 'Operazione di mappatura annullata.';de = 'Der Mappingvorgang wurde abgebrochen.'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillChoiseLists()
	
	FinancialAccounting.FillChartOfAccountsList(Items.SourceChartOfAccounts.ChoiceList);
	FinancialAccounting.FillChartOfAccountsList(Items.ReceivingChartOfAccounts.ChoiceList);
	
EndProcedure

&AtServer
Procedure FillReceivingResourceChoiceList()
	
	Items.ReceivingResource.ChoiceList.Clear();
	
	If ValueIsFilled(Object.ReceivingAccountingRegister) Then
		
		AccountingRegisterName	= Common.ObjectAttributeValue(Object.ReceivingAccountingRegister, "Name");
		Resources				= Metadata.AccountingRegisters[AccountingRegisterName].Resources;
		
		For Each Resource In Resources Do
			Items.ReceivingResource.ChoiceList.Add(Resource.Name, Resource.Synonym);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChartOfAccountsOnChangeAtServer(IsReceiver = False)
	
	If IsReceiver Then
		
		SetAccountingRegister(Object.ReceivingChartOfAccounts, Object.ReceivingAccountingRegister);
		FillReceivingResourceChoiceList();
		
		For Each Row In Object.ResourceCompliance Do
			Row.ReceivingResource = "";
		EndDo;
		
	Else
		SetAccountingRegister(Object.SourceChartOfAccounts, Object.SourceAccountingRegister);
		FillResourceCompliance();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetAccountingRegister(ChartOfAccounts, AccountingRegister)
	
	AccountingRegister = FinancialAccounting.GetAccountinRegisterByChartOfAccounts(ChartOfAccounts);
	
EndProcedure

&AtServer
Procedure FillResourceCompliance()
	
	Object.ResourceCompliance.Clear();
	
	If ValueIsFilled(Object.SourceAccountingRegister) Then
		
		AccountingRegisterName	= Common.ObjectAttributeValue(Object.SourceAccountingRegister, "Name");
		Resources				= Metadata.AccountingRegisters[AccountingRegisterName].Resources;
		
		For Each Resource In Resources Do
			
			ResourceCompliance = Object.ResourceCompliance.Add();
			ResourceCompliance.SourceResource = Resource.Name;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CopyingMappingSettings(Cancel, CurrentObject)
	
	If ValueIsFilled(CopyingObject) Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	MappingRules.TranslationTemplate AS TranslationTemplate,
		|	MappingRules.AccountsMapping AS AccountsMapping,
		|	MappingRules.UseDr AS UseDr,
		|	MappingRules.UseCr AS UseCr,
		|	MappingRules.CorrSourceAccount AS CorrSourceAccount
		|FROM
		|	InformationRegister.MappingRules AS MappingRules
		|WHERE
		|	MappingRules.TranslationTemplate = &TranslationTemplate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Mapping.Description AS Description,
		|	Mapping.SourceAccount AS SourceAccount,
		|	Mapping.ReceivingAccount AS ReceivingAccount,
		|	Mapping.CorrSourceAccount AS CorrSourceAccount,
		|	Mapping.MappingID AS MappingID,
		|	Mapping.Ref AS Ref
		|FROM
		|	Catalog.Mapping AS Mapping
		|WHERE
		|	Mapping.Owner = &TranslationTemplate";
		
		Query.SetParameter("TranslationTemplate", CopyingObject);
		
		Result = Query.ExecuteBatch();
		
		MappingRulesTable = Result[0].Unload();
		MappingTable = Result[1].Unload();
		
		Try
			
			BeginTransaction();
			
			For Each MappingRow In MappingTable Do
				
				NewMappingItem = Catalogs.Mapping.CreateItem();
				FillPropertyValues(NewMappingItem, MappingRow);
				NewMappingItem.Owner = CurrentObject.Ref;
				NewMappingItem.Write();
				
				RecordSet = InformationRegisters.MappingRules.CreateRecordSet();
				RecordSet.Filter.TranslationTemplate.Set(CurrentObject.Ref);
				RecordSet.Filter.AccountsMapping.Set(NewMappingItem.Ref);
				
				SearchStructure = New Structure("TranslationTemplate, AccountsMapping", CopyingObject, MappingRow.Ref);
				MappingRulesRows = MappingRulesTable.FindRows(SearchStructure);
				For Each MappingRulesRow In MappingRulesRows Do
					
					Record = RecordSet.Add();
					FillPropertyValues(Record, MappingRulesRow, , "TranslationTemplate, AccountsMapping");
					Record.TranslationTemplate = CurrentObject.Ref;
					Record.AccountsMapping = NewMappingItem.Ref;
					
				EndDo;
				
				RecordSet.Write();
				
			EndDo;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			CommonClientServer.MessageToUser(NStr("en = 'Cannot save mapping settings'; ru = 'Не удалось сохранить настройки сопоставления';pl = 'Nie udało się zapisać ustawień mapowania.';es_ES = 'No se ha podido guardar la configuración del mapeo';es_CO = 'No se ha podido guardar la configuración del mapeo';tr = 'Bağlantı ayarları kaydedilemedi.';it = 'Impossibile salvare le impostazioni di mappatura';de = 'Die Mappingeinstellungen konnten nicht gespeichert werden'"), , , , Cancel);
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion