#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ChangeStatusWithCheck(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	TemplatesTable = Undefined;
	
	If Not ParametersStructure.Property("TemplatesTable", TemplatesTable) Then
		Return;
	EndIf;
	
	NewTemplateParameters = ParametersStructure.NewTemplateParameters;
	
	For Each TemplateRow In TemplatesTable Do
		
		If TemplateRow.Error = 0 Then // Template already processed
			Continue;
		EndIf;
		
		TemplateRow.Error = CheckStatusChangeAvailable(TemplateRow.TemplateRef, NewTemplateParameters);
		
	EndDo;
	
	ResultStructure = New Structure();
	ResultStructure.Insert("Messages", TimeConsumingOperations.UserMessages(True));
	ResultStructure.Insert("TemplatesTable", TemplatesTable);
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);

EndProcedure 

Function CheckSubordinateTemplates(Object) Export
	
	ReturnStructure = New Structure("IsUsed, IsPeriodMatch, IsActive", False, False, False);
	ReturnStructure.Insert("TemplatesArray", New Array);
	
	If Not ValueIsFilled(Object.Ref) Then
		Return ReturnStructure;
	EndIf;
	
	CurrentAttValues = Common.ObjectAttributesValues(Object.Ref, "Status, StartDate, EndDate");
	DraftStatus		 = Enums.AccountingEntriesTemplatesStatuses.Draft;
	ActiveStatus	 = Enums.AccountingEntriesTemplatesStatuses.Active;
	
	If CurrentAttValues.Status = ActiveStatus And Object.Status = DraftStatus Then // Active -> Draft
		
		ActiveTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplateUsage(Object.Ref, ActiveStatus);
		ActiveTransTemplTable.GroupBy("Ref, Code");
		
		For Each TransTempl In ActiveTransTemplTable Do
			
			ReturnStructure.IsUsed		= True;
			ReturnStructure.IsActive	= True;
			
			UsedTemplates = New Structure;
			UsedTemplates.Insert("Code"		, TransTempl.Code);
			UsedTemplates.Insert("Ref"		, TransTempl.Ref);
			UsedTemplates.Insert("Active"	, True);
			
			ReturnStructure.TemplatesArray.Add(UsedTemplates);
		EndDo;
		
		If Not ReturnStructure.IsActive Then
			
			DraftTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplateUsage(Object.Ref, DraftStatus);
			DraftTransTemplTable.GroupBy("Ref, Code");
			
			For Each TransTempl In DraftTransTemplTable Do
				ReturnStructure.IsUsed = True;
				
				UsedTemplates = New Structure;
				UsedTemplates.Insert("Code"		, TransTempl.Code);
				UsedTemplates.Insert("Ref"		, TransTempl.Ref);
				UsedTemplates.Insert("Active"	, False);
				
				ReturnStructure.TemplatesArray.Add(UsedTemplates);
			EndDo;
			
		EndIf;
		
	ElsIf CurrentAttValues.Status = ActiveStatus And Object.Status = ActiveStatus Then // Status is the same, but activity period is changing.
		
		ActiveTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplatePeriodsNotMatch(
			Object.Ref,
			ActiveStatus,
			Object.StartDate,
			Object.EndDate);
		ActiveTransTemplTable.GroupBy("Ref, Code, StartDate, EndDate");
		
		For Each TransTempl In ActiveTransTemplTable Do
			ReturnStructure.IsPeriodMatch	= True;
			ReturnStructure.IsActive		= True;
		
			TransPeriodTemplate = StrTemplate(
				"%1 - %2",
				Format(TransTempl.StartDate , "DLF=D; DE=..."),
				Format(TransTempl.EndDate	, "DLF=D; DE=..."));
				
			NotMatchedPeriodStructure = New Structure;
			NotMatchedPeriodStructure.Insert("Code"		, TransTempl.Code);
			NotMatchedPeriodStructure.Insert("Ref"		, TransTempl.Ref);
			NotMatchedPeriodStructure.Insert("Period"	, TransPeriodTemplate);
			NotMatchedPeriodStructure.Insert("Active"	, True);
			
			ReturnStructure.TemplatesArray.Add(NotMatchedPeriodStructure);
		EndDo;
		
		If Not ReturnStructure.IsActive Then 
			DraftTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplatePeriodsNotMatch(
				Object.Ref,
				DraftStatus,
				Object.StartDate,
				Object.EndDate);
			DraftTransTemplTable.GroupBy("Ref, Code, StartDate, EndDate");
			
			For Each TransTempl In DraftTransTemplTable Do
				ReturnStructure.IsPeriodMatch = True;
				
				TransPeriodTemplate = StrTemplate("%1 - %2",
					Format(TransTempl.StartDate , "DLF=D; DE=..."),
					Format(TransTempl.EndDate	, "DLF=D; DE=..."));
					
				NotMatchedPeriodStructure = New Structure;
				NotMatchedPeriodStructure.Insert("Code"		, TransTempl.Code);
				NotMatchedPeriodStructure.Insert("Ref"		, TransTempl.Ref);
				NotMatchedPeriodStructure.Insert("Period"	, TransPeriodTemplate);
				NotMatchedPeriodStructure.Insert("Active"	, False);
				
				ReturnStructure.TemplatesArray.Add(NotMatchedPeriodStructure);
			EndDo;
		EndIf;
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)

	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.AccountingEntriesTemplates);

EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);

EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);

EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure RenameDataSource() Export 
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Table.Ref AS Ref
	|INTO TT_Refs
	|FROM
	|	Catalog.AccountingEntriesTemplates.ElementsSynonyms AS Table
	|WHERE
	|	Table.MetadataName = ""DataSource""
	|	AND Table.Synonym LIKE &InventoryDiscrepancyCost1
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS Table
	|WHERE
	|	Table.DataSource LIKE &InventoryDiscrepancyCost2
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS Table
	|WHERE
	|	Table.DataSource LIKE &InventoryDiscrepancyCost2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Refs.Ref AS Ref
	|FROM
	|	TT_Refs AS TT_Refs";
	
	Query.SetParameter("InventoryDiscrepancyCost1", "%Inventory - Discrepancy cost%");
	Query.SetParameter("InventoryDiscrepancyCost2", "%InventoryDiscrepancyCost%");
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		If CatalogObject = Undefined Then
			Continue;
		EndIf;
		
		For Each Row In CatalogObject.Entries Do
			
			Row.DataSource = StrReplace(Row.DataSource, 
				"InventoryDiscrepancyCost",
				"GoodsReceivedNotInvoicedDiscrepancyCost");
			
		EndDo;
		
		For Each Row In CatalogObject.EntriesSimple Do
			
			Row.DataSource = StrReplace(Row.DataSource, 
				"InventoryDiscrepancyCost",
				"GoodsReceivedNotInvoicedDiscrepancyCost");
			
		EndDo;
		
		For Each Row In CatalogObject.ElementsSynonyms Do
			
			Row.Synonym = StrReplace(Row.Synonym,
				"Inventory - Discrepancy cost",
				"Goods received not invoiced - Discrepancy cost");
			
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(CatalogObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.AccountingEntriesTemplates,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion 

#EndRegion 

#Region Private

Function RunTemplateCheck(Template, NewTemplateParameters)

	TemplateObject = Template.GetObject();
	
	If NewTemplateParameters.Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		
		If Not ValueIsFilled(TemplateObject.PlanStartDate) Then
			TemplateObject.PlanStartDate = TemplateObject.StartDate; 
		EndIf;
		If Not ValueIsFilled(TemplateObject.PlanEndDate) Then
			TemplateObject.PlanEndDate 	 = TemplateObject.EndDate;
		EndIf;
		
	Else
		
		TemplateObject.PlanStartDate = Undefined; 
		TemplateObject.PlanEndDate 	 = Undefined;
		
	EndIf;
	
	FillPropertyValues(TemplateObject, NewTemplateParameters);
	
	CorrectFilling = TemplateObject.CheckFilling();
	
	TemplateObject.AdditionalProperties.Insert("SubordinateTemplatesClearing", True);
	
	If CorrectFilling Then
		Try
			TemplateObject.Write();
		Except
			
			MessageText = StrTemplate(NStr("en = 'Cannot change template status. %1'; ru = 'Не удалось изменить статус шаблона. %1';pl = 'Nie można zmienić statusu szablonu. %1';es_ES = 'No se puede cambiar el estado de la plantilla. %1';es_CO = 'No se puede cambiar el estado de la plantilla. %1';tr = 'Şablon durumu değiştirilemiyor. %1';it = 'Impossibile modificare lo stato del modello. %1';de = 'Fehler beim Ändern des Status der Vorlage. %1'"), DetailErrorDescription(ErrorInfo()));
			EventName = AccountingTemplatesPosting.GetEventGroupVariant()
				+ NStr("en = 'Status change'; ru = 'Изменение статуса';pl = 'Zmiana statusu';es_ES = 'Cambio de estado';es_CO = 'Cambio de estado';tr = 'Durum değişikliği';it = 'Modificare stato';de = 'Ändern des Status'", CommonClientServer.DefaultLanguageCode());
			WriteLogEvent(EventName, EventLogLevel.Error, TemplateObject.Ref, , MessageText);
			
			Return 1;
			
		EndTry;
		
		Return 0;
	Else
		Return 1;
	EndIf;
	
EndFunction 

Function CheckStatusChangeAvailable(Template, NewTemplateParameters)

	CurrentData = Common.ObjectAttributesValues(Template, "Status, StartDate, EndDate");
	
	If CurrentData.Status = NewTemplateParameters.Status 
		And CurrentData.StartDate = NewTemplateParameters.StartDate
		And CurrentData.EndDate = NewTemplateParameters.EndDate Then
		
		Return 0;
		
	Else
		
		Return RunTemplateCheck(Template, NewTemplateParameters);
		
	EndIf;

EndFunction

#EndRegion

#EndIf