#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CopyDynamicAttributes(Parameters.CopyingValue);
	
	SetComplexTypeOfEntries();
	
	InitSimpleEntries();
	
	InitSynonyms();
	
	SetTSNumberPresentations();
	
	PositionToGivenElement();
	
	FillCurrentObjectAttributes();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	SetEnabledByRight();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	MapTabSections();
	
	SetComplexTypeOfEntries();
	
	SetRestrictedStatus();
	
	InitSimpleEntries();
	
	InitSynonyms();
	
	SetTSNumberPresentations();
	
	FillCurrentObjectAttributes();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SerializeParametersConditions(CurrentObject);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetRestrictedStatus();
	InitSimpleEntries();
	InitSynonyms();
	MapTabSections();
	SetTSNumberPresentations();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	FillCurrentObjectAttributes();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetTSNumberPresentations();
	SetStatusPeriodVisibility();
	
	If WriteParameters.Property("OpenTestTemplateForm") Then
		OpenTestTemplateForm();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetStatusPeriodVisibility();
	SetEntriesTabVisibility();
	SetMovingButtonsEnabled();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EntiesFiltersEdit"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID Then
		
		GetEntriesFiltersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.ObjectsPropertiesValues.Form.ListForm" Then
		
		CurrentData = Items.Parameters.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		CurrentData.ValuePresentation = SelectedValue;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	SubordTemplStructure = CheckSubordinateTemplates();
	
	If Not SubordTemplStructure.IsUsed And Not SubordTemplStructure.IsPeriodMatch Or SubordTemplStructure.ModifiedContent Then
		Return;
	EndIf;
	
	Cancel = True;

	If SubordTemplStructure.IsUsed Then
		ErrorTemplate = NStr("en = 'This template is applied to Accounting transaction template {%1} with the %2 status.'; ru = 'Этот шаблон применяется в шаблоне бухгалтерских операций {%1} со статусом %2.';pl = 'Szablon jest stosowany do szablonu Transakcji księgowej {%1} o statusie %2.';es_ES = 'Esta plantilla se aplica a la plantilla de transacción contable {%1} con el estado %2.';es_CO = 'Esta plantilla se aplica a la plantilla de transacción contable {%1} con el estado %2.';tr = 'Bu şablon, %2 durumlu {%1} Muhasebe işlemi şablonuna uygulanıyor.';it = 'Questo modello è applicato al modello di transazione di contabilità {%1} con stato %2.';de = 'Diese Vorlage ist für Buchhaltungstransaktionsvorlage {%1} mit dem Status %2 verwendet.'");
		
		For Each UsedTemplate In SubordTemplStructure.TemplatesArray Do
			
			StatusText = ?(UsedTemplate.Active, NStr("en = 'Active'; ru = 'Активен';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'"), NStr("en = 'Draft'; ru = 'Черновик';pl = 'Wersja robocza';es_ES = 'Borrador';es_CO = 'Borrador';tr = 'Taslak';it = 'Bozza';de = 'Entwurf'"));
			
			ErrMessage = StrTemplate(ErrorTemplate, UsedTemplate.Code, StatusText);
			CommonClientServer.MessageToUser(ErrMessage, UsedTemplate.Ref);
			
		EndDo;

	ElsIf SubordTemplStructure.IsPeriodMatch Then
		
		ErrorTemplate = NStr("en = 'Accounting transaction template {%1}: new template validity period {%2} 
			|does not match the validity period {%3} of the Accounting transaction template with the %4 status.'; 
			|ru = 'Шаблон бухгалтерских операций {%1}: новый срок действия шаблона {%2}
			|не соответствует сроку действия {%3} шаблона бухгалтерских операций со статусом %4.';
			|pl = 'Szablon transakcji księgowej {%1}: okres ważności nowego szablonu {%2} 
			|nie jest zgodny z okresem ważności {%3} szablonu Transakcji księgowej o statusie %4.';
			|es_ES = 'Plantilla de entradas contables {%1}: el nuevo periodo de validez de la plantilla {%2} 
			|no coincide con el periodo de validez {%3} de la plantilla de Transacción contable con el estado %4.';
			|es_CO = 'Plantilla de entradas contables {%1}: el nuevo periodo de validez de la plantilla {%2} 
			|no coincide con el periodo de validez {%3} de la plantilla de Transacción contable con el estado %4.';
			|tr = 'Muhasebe işlem şablonu {%1}: Yeni şablon geçerlilik dönemi {%2} 
			|%4 durumlu Muhasebe işlem şablonunun {%3} geçerlilik dönemi ile eşleşmiyor.';
			|it = 'Modello di transazione di contabilità {%1}: il nuovo periodo di validità del modello {%2}
			| non corrisponde al periodo di validità {%3}del modello di transazione di contabilità con stato %4.';
			|de = 'Buchhaltungstransaktionsvorlage {%1}: neue Gültigkeitsdauer von Vorlage {%2}
			| stimmt mit der Gültigkeitsdauer {%3}der Vorlage von Buchhaltungstransaktion mit dem Status %4 nicht überein.'");
		
		NewPeriodTemplate = StrTemplate("%1 - %2", Format(Object.StartDate, "DLF=D; DE=..."), Format(Object.EndDate, "DLF=D; DE=..."));
		
		For Each NotMatchedPeriod In SubordTemplStructure.TemplatesArray Do
			
			StatusText = ?(NotMatchedPeriod.Active, NStr("en = 'Active'; ru = 'Активен';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'"), NStr("en = 'Draft'; ru = 'Черновик';pl = 'Wersja robocza';es_ES = 'Borrador';es_CO = 'Borrador';tr = 'Taslak';it = 'Bozza';de = 'Entwurf'"));
			
			ErrMessage = StrTemplate(ErrorTemplate, NotMatchedPeriod.Code, NewPeriodTemplate, NotMatchedPeriod.Period, StatusText);
			CommonClientServer.MessageToUser(ErrMessage, NotMatchedPeriod.Ref, "PlanStartDate");
			
		EndDo;
	
	EndIf;
	
	If SubordTemplStructure.IsActive Then
		
		ErrorTitle = NStr("en = 'Cannot change the template status. This template is already applied to Accounting transaction template with the Active status.'; ru = 'Не удалось изменить статус шаблона. Этот шаблон уже применен в шаблоне бухгалтерских операций со статусом ""Активен"".';pl = 'Nie można zmienić statusu szablonu. Ten szablon jest już zastosowany do szablonu transakcji księgowej o statusie Aktywny.';es_ES = 'No se puede cambiar el estado de la plantilla. Esta plantilla ya está aplicada a la plantilla de transacciones contables con el estado Activo.';es_CO = 'No se puede cambiar el estado de la plantilla. Esta plantilla ya está aplicada a la plantilla de transacciones contables con el estado Activo.';tr = 'Şablon durumu değiştirilemiyor. Bu şablon, Aktif durumlu Muhasebe işlemi şablonuna uygunlanmış durumda.';it = 'Impossibile modificare lo stato del modello. Questo modello è già applicato al modello di transazione di contabilità con stato Attivo.';de = 'Fehler beim Ändern des Status der Vorlage. Diese Vorlage ist für Buchhaltungstransaktionsvorlage mit dem Status Aktiv bereits verwendet.'");
		ShowMessageBox( , ErrorTitle);
		
	Else
		
		SubordinateTemplatesCheckInProgress = True;
		
		ErrorTitle = NStr("en = 'This template is already applied to some of the Accounting transaction templates with the Draft status. 
			|If you continue, the templates entries will be automatically deleted from the Accounting transaction templates. 
			|Do you want to continue?'; 
			|ru = 'Этот шаблон уже применяется к некоторым шаблонам бухгалтерских операций со статусом ""Черновик"". 
			|При продолжении, бухгалтерские проводки шаблонов будут автоматически удалены из шаблонов бухгалтерских операций. 
			|Продолжить?';
			|pl = 'Ten szablon jest już zastosowany do niektórych szablonów transakcji księgowych o statusie Wersja robocza. 
			|W razie kontynuowania wpisy szablonów zostaną automatycznie usunięte z szablonów transakcji księgowych. 
			|Czy chcesz kontynuować?';
			|es_ES = 'Esta plantilla ya se aplica a algunas de las plantillas de transacciones contables con el estado de Borrador. 
			|Si continúas, las entradas de diario se borrarán automáticamente de las plantillas de transacciones contables. 
			|¿Quieres continuar?';
			|es_CO = 'Esta plantilla ya se aplica a algunas de las plantillas de transacciones contables con el estado de Borrador. 
			|Si continúas, las entradas de diario se borrarán automáticamente de las plantillas de transacciones contables. 
			|¿Quieres continuar?';
			|tr = 'Bu şablon, Taslak durumundaki bazı Muhasebe işlemi şablonlarına uygulanıyor. 
			|Devam ederseniz, şablon girişleri otomatik olarak Muhasebe işlemi şablonlarından silinecek. 
			|Devam etmek istiyor musunuz?';
			|it = 'Questo modello è già applicato ad alcuni dei modelli di transazione di contabilità con stato Bozza.
			|Continuando, le voci dei modelli sarano eliminate automaticamente dai modelli di transazione di contabilità.
			|Continuare?';
			|de = 'Diese Vorlage ist für mehrere Buchhaltungstransaktionsvorlagen mit dem Status Entwurf verwendet. 
			|Fahren Sie fort, werden die Vorlagen Buchungen aus den Buchhaltungstransaktionsvorlagen automatisch gelöscht. 
			|Möchten Sie fortfahren?'");
		Notify = New NotifyDescription("ClearingTemplateRequestEnd", ThisObject);
		ShowQueryBox(Notify, ErrorTitle, QuestionDialogMode.YesNo, 0);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If SubordinateTemplatesCheckInProgress Then
		FormClosing	= True;
		Cancel		= True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StatusOnChange(Item)
	
	SetStatusPeriodVisibility();
	SetDates();
	
EndProcedure

&AtClient
Procedure DocumentTypeOnChange(Item)
	
	UpdateDescription(CurrentDocumentType, Object.DocumentType);
	CurrentDocumentType = Object.DocumentType;
	
EndProcedure

&AtClient
Procedure DocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "ChartOfAccounts");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Charts of accounts'; ru = 'Планы счетов';pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planları';it = 'Piani dei conti';de = 'Kontenpläne'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChartOfAccounts"	, Object.ChartOfAccounts);
	ChoiceFormParameters.Insert("FillDocumentType"	, True);
	ChoiceFormParameters.Insert("CurrentValue"		, Object.DocumentType);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'document type'; ru = 'тип документа';pl = 'typ dokumentu';es_ES = 'tipo de documento';es_CO = 'tipo de documento';tr = 'belge türü';it = 'tipo di documento';de = 'Dokumententyp'"));
	ChoiceFormParameters.Insert("AttributeID"		, "DocumentType");
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "DocumentType");
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("DocumentTypeChoiceFragment", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure DocumentTypeChoiceEnding(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		
		Return;
		
	ElsIf Result = DialogReturnCode.Yes Then
		
		AttributesList = AdditionalParameters.AttributesList;
		
		For Each Attribute In AttributesList Do
			
			If Attribute.Field = "ParameterName" Then
				Object[Attribute.TabName].Delete(Attribute.Row);
			Else
				Attribute.Row[Attribute.Field] = Undefined;
				Attribute.Row[Attribute.Field + "Synonym"] = Undefined;
			EndIf;
			
		EndDo;
		
		ClearDataSources(AdditionalParameters.ClosingResult.Field);
		
	EndIf;
	
	ClosingResult = AdditionalParameters.ClosingResult;
	Object.DocumentType = ClosingResult.Field;
	UpdateDescription(CurrentDocumentType, Object.DocumentType);
	CurrentDocumentType = Object.DocumentType;
	Object.DocumentTypeSynonym = ClosingResult.Synonym;
	
	WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(Object, "DocumentType", 0, ClosingResult.Synonym);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure DocumentTypeChoiceFragment(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	AddParameters = New Structure;
	AddParameters.Insert("ClosingResult", ClosingResult);
	
	If ValueIsFilled(CurrentDocumentType) And CurrentDocumentType <> ClosingResult.Field Then
		
		FieldStructure = GetFieldStructureForChecking();
		
		FieldsToRemove = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
			Object,
			GetDocumentTypeName(CurrentDocumentType),
			"DocumentType",
			FieldStructure);
		
		DataSourceArray				= GetAvailableDataSourcesTable(ClosingResult.Field);
		FieldEntriesStructure		= GetFieldStructureForChecking("Entries");
		FieldsToRemoveDataEntries	= New Array;
		For Each Row In Object.Entries Do
			
			
			If Not ValueIsFilled(Row.DataSource) Or DataSourceArray.Find(Row.DataSource) <> Undefined Then
				Continue;
			EndIf;
			
			FieldsToRemoveDataEntries = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(Row, Row.DataSource,
				"DataSource", FieldEntriesStructure);
			
		EndDo;
		
		FieldEntriesSimpleStructure		= GetFieldStructureForChecking("EntriesSimple");
		FieldsToRemoveDataEntriesSimple = New Array;
		For Each Row In Object.EntriesSimple Do
			
			If Not ValueIsFilled(Row.DataSource) Or DataSourceArray.Find(Row.DataSource) <> Undefined Then
				Continue;
			EndIf;
			
			FieldsToRemoveDataEntriesSimple = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(Row, Row.DataSource,
				"DataSource", FieldEntriesSimpleStructure);
			
		EndDo;
		
		If FieldsToRemove.Count() > 0 Or FieldsToRemoveDataEntries.Count() > 0
			Or FieldsToRemoveDataEntriesSimple.Count() > 0 Then
			
			MessageTemplate	= NStr("en = 'All fields dependent on %1 fields will be cleared. Continue?'; ru = 'Все поля, зависящие от полей %1, будут очищены. Продолжить?';pl = 'Wszystkie pola zależne od pól %1 zostaną wyczyszczone. Kontynuować?';es_ES = 'Todos los campos que dependen de los %1 campos se borrarán. ¿Continuar?';es_CO = 'Todos los campos que dependen de los %1 campos se borrarán. ¿Continuar?';tr = '%1 alanlarına bağlı tüm alanlar temizlenecek. Devam edilsin mi?';it = 'Tutti i campi dipendenti dal campo %1 saranno cancellati. Continuare?';de = 'Alle von Feldern %1 abhängigen Felder werden gelöscht. Weiter?'");
			MessageText		= StrTemplate(MessageTemplate, CurrentDocumentType);
			
			AddParameters.Insert("AttributesList", FieldsToRemove);
			
			ShowQueryBox(
				New NotifyDescription("DocumentTypeChoiceEnding", ThisObject, AddParameters),
				MessageText, QuestionDialogMode.YesNo);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	DocumentTypeChoiceEnding(Undefined, AddParameters);
	
EndProcedure

&AtClient
Procedure ChartOfAccountsOnChange(Item)
	
	If ValueIsFilled(Object.DocumentType) And Not CheckDocumentTypeForChartOfAccounts() Then
		
		QueryTemplate = NStr("en = 'The %1 is not applicable to %2. The template data will be cleared. Continue?'; ru = '%1 неприменим к %2. Данные шаблона будут удалены. Продолжить?';pl = '%1 nie dotyczy %2. Dane szablonu zostaną wyczyszczone. Kontynuować?';es_ES = 'El %1 no es aplicable a%2. Los datos de la plantilla se borrarán. ¿Continuar?';es_CO = 'El %1 no es aplicable a%2. Los datos de la plantilla se borrarán. ¿Continuar?';tr = '%1 şuna uygulanamıyor: %2. Şablon verileri silinecek. Devam edilsin mi?';it = '%1 non è applicabile a %2. I dati del modello saranno cancellati. Continuare?';de = '%1 ist für %2 nicht verwendbar. Die Vorlagendaten werden gelöscht. Weiter?'");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("DocumentType", True);
		
		ShowQueryBox(New NotifyDescription("ChartOfAccountsOnChangeEnd", ThisObject, AdditionalParameters),
			StrTemplate(QueryTemplate, Object.DocumentType, Object.ChartOfAccounts),
			QuestionDialogMode.YesNo,
			0);
		
		Return;
		
	EndIf;
	
	ChartOfAccountsOnChangeEnd(Undefined, New Structure);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region ParametersFormTableItemsEventHandlers

&AtClient
Procedure ParametersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersParameterStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
		
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DocumentType"	, Object.DocumentType);
	ChoiceFormParameters.Insert("FillParameters", True);
	ChoiceFormParameters.Insert("AttributeName"	, NStr("en = 'parameter'; ru = 'параметр';pl = 'parametr';es_ES = 'parámetro';es_CO = 'parámetro';tr = 'parametre';it = 'parametro';de = 'Parameter'"));
	ChoiceFormParameters.Insert("AttributeID"	, "Parameter");
	ChoiceFormParameters.Insert("CurrentValue"	, Items.Parameters.CurrentData.ParameterName);
		
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("ParametersParameterChoiceEnding", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ParametersParameterChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.ParameterName		= ClosingResult.Field;
	CurrentData.ParameterSynonym	= ClosingResult.Synonym;
	CurrentData.ValueType			= ClosingResult.ValueType;
	CurrentData.ValuePresentation	= ClosingResult.ValueType.AdjustValue(CurrentData.ValuePresentation);
	CurrentData.MultipleValuesMode	=
		WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		Object.ParametersValues,
		ValueListOneValue,
		"Parameters",
		CurrentData.ValuesConnectionKey,
		"ConnectionKey");
		
	SetChoiceParameters();
	
EndProcedure

&AtClient
Procedure ParametersParameterClearing(Item, StandardProcessing)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.ValuePresentation	= Undefined;
	CurrentData.ValueType			= Undefined;
	
EndProcedure

&AtClient
Procedure ParametersValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "ParameterSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Parameter'; ru = 'Параметр';pl = 'Parametr';es_ES = 'Parámetro';es_CO = 'Parámetro';tr = 'Parametre';it = 'Parametro';de = 'Parameter'"));
	FieldStructure.Insert("ObjectName"	, "Object.Parameters");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray) Then
		StandardProcessing = False;
		Return;
	EndIf;

	If CurrentData.MultipleValuesMode Then
		OpenInputValuesInListForm();
		StandardProcessing = False;
	EndIf;
	
	ParameterNameArray = StrSplit(CurrentData.ParameterName, ".");
	
	If ParameterNameArray.Count() < 3
		Or (ParameterNameArray[1] <> "AdditionalAttribute"
			And ValueIsFilled(CurrentData.ValueType)) Then
			
		If CurrentData.ValueType.Types().Count() > 1 Then
			Item.TypeRestriction = CurrentData.ValueType;
			Item.ChooseType = True;
		Else
			Item.TypeRestriction = New TypeDescription;
			Item.ChooseType = False;
		EndIf;
		
		Return;
		
	EndIf;
	
	TypeObjectsPropertiesValues = Type("CatalogRef.ObjectsPropertiesValues");
	
	If Not CurrentData.ValueType.ContainsType(TypeObjectsPropertiesValues) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	SelectionFormOwner = WorkWithArbitraryParametersClient.GetAdditionalParameterType(ParameterNameArray[2]);
	
	FormFilter = New Structure("Owner", SelectionFormOwner);
	
	FormParameters = New Structure("Filter", FormFilter);
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.ObjectsPropertiesValues.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ParametersValueOnChange(Item)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Or CurrentData.MultipleValuesMode Then
		Return;
	EndIf;

	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	ChangeEmptyValues = StrFind(CurrentData.ParameterName, ".AdditionalAttribute.") <> 0;
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		Object.ParametersValues,
		ValueListOneValue,
		"Parameters",
		CurrentData.ValuesConnectionKey,
		"ConnectionKey",
		ChangeEmptyValues);

EndProcedure

&AtClient
Procedure ParametersConditionPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "ParameterSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Parameter'; ru = 'Параметр';pl = 'Parametr';es_ES = 'Parámetro';es_CO = 'Parámetro';tr = 'Parametre';it = 'Parametro';de = 'Parameter'"));
	FieldStructure.Insert("ObjectName"	, "Object.Parameters");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray) Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	WorkWithArbitraryParametersClient.SetAvailableComparasingTypesList(CurrentData, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ParametersConditionPresentationOnChange(Item)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentMultipleValuesMode = CurrentData.MultipleValuesMode;
	
	CurrentData.MultipleValuesMode = WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);
	
	If CurrentData.MultipleValuesMode <> CurrentMultipleValuesMode And CurrentMultipleValuesMode Then
		
		WorkWithArbitraryParametersClient.ProcessMultipleToSingleValue(
			Object.ParametersValues,
			"Parameters",
			CurrentData);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure OpenInputValuesInListForm()

	ChoiceFormParameters = WorkWithArbitraryParametersClient.FilterSelectionParameters(
		Items.Parameters.CurrentData,
		Object.ParametersValues,
		"Parameters");
		
	Handler	= New NotifyDescription("ListCompleteChoice", ThisObject);
	Block	= FormWindowOpeningMode.LockOwnerWindow;
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes", ChoiceFormParameters, ThisObject, , , , Handler, Block);

EndProcedure 

&AtClient
Procedure ListCompleteChoice(SelectionResult, HandlerParameters) Export
	
	If TypeOf(SelectionResult) <> Type("ValueList") Then
		Return;
	EndIf;
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	ChangeEmptyValues = StrFind(CurrentData.ParameterName, ".AdditionalAttribute.") <> 0;
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		Object.ParametersValues,
		SelectionResult,
		"Parameters",
		CurrentData.ValuesConnectionKey,
		"ConnectionKey",
		ChangeEmptyValues);
		
	CurrentData.ValuePresentation = WorkWithArbitraryParametersClient.ValueArrayPresentation(SelectionResult);
	
EndProcedure

&AtClient
Procedure ParametersBeforeDeleteRow(Item, Cancel)
	
	WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(
		Object.ParametersValues,
		"Parameters",
		Item.CurrentData.ValuesConnectionKey);
		
EndProcedure

&AtClient
Procedure ParametersOnActivateRow(Item)

	SetChoiceParameters();
	
EndProcedure

#EndRegion

#Region EntriesFormTableItemsEventHandlers

&AtClient
Procedure EntriesDataSourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.Entries.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("FillDataSources"	, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'data source'; ru = 'источник данных';pl = 'źródło danych';es_ES = 'fuente de datos';es_CO = 'fuente de datos';tr = 'veri kaynağı';it = 'fonte dati';de = 'Datenquelle'"));
	ChoiceFormParameters.Insert("AttributeID"		, "DataSource");
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.DataSource);
	
	CurrentDataSource			= CurrentData.DataSource;
	CurrentDataSourceSynonym	= CurrentData.DataSourceSynonym;
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "DataSource");
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters),
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesDataSourceOnChange(Item)
	
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");

	CurrentData = Items[EntriesTabName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentDataSource) And CurrentDataSource <> CurrentData.DataSource Then
		
		FieldsStructure		= GetFieldStructureForChecking(EntriesTabName);
		
		Filter = New Structure;
		Filter.Insert("EntryConnectionKey", CurrentData.ConnectionKey);
		
		FilterRows = Object.EntriesFilters.FindRows(Filter);
		
		AllFieldsToRemoveData = New Array;
		For Each Row In FilterRows Do
			
			FilterFieldsStructure = GetFieldStructureForChecking("EntriesFilters");
			FieldsToRemoveData	= WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
				Row,
				CurrentDataSource,
				"DataSource",
				FilterFieldsStructure);
				
				For Each Field In FieldsToRemoveData Do
					
					FieldStructure = New Structure;
					FieldStructure.Insert("Row"			, Row);
					FieldStructure.Insert("Field"		, Field);
					FieldStructure.Insert("DeleteRow"	, True);
					FieldStructure.Insert("TabSection"	, Object.EntriesFilters);
					
					AllFieldsToRemoveData.Add(FieldStructure);
					
				EndDo;
				
		EndDo;
		
		FieldsToRemoveData	= WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
			CurrentData,
			CurrentDataSource,
			"DataSource",
			FieldsStructure);
			
			For Each Field In FieldsToRemoveData Do
				
				FieldStructure = New Structure;
				FieldStructure.Insert("Row"			, CurrentData);
				FieldStructure.Insert("Field"		, Field);
				FieldStructure.Insert("DeleteRow"	, False);
				
				AllFieldsToRemoveData.Add(FieldStructure);
				
			EndDo;
			
		If AllFieldsToRemoveData.Count() > 0 Then
			
			MessageTemplate	= NStr("en = 'All fields dependent on %1 fields will be cleared. Continue?'; ru = 'Все поля, зависящие от полей %1, будут очищены. Продолжить?';pl = 'Wszystkie pola zależne od pól %1 zostaną wyczyszczone. Kontynuować?';es_ES = 'Todos los campos que dependen de los %1 campos se borrarán. ¿Continuar?';es_CO = 'Todos los campos que dependen de los %1 campos se borrarán. ¿Continuar?';tr = '%1 alanlarına bağlı tüm alanlar temizlenecek. Devam edilsin mi?';it = 'Tutti i campi dipendenti dal campo %1 saranno cancellati. Continuare?';de = 'Alle von Feldern %1 abhängigen Felder werden gelöscht. Weiter?'");
			MessageText		= StrTemplate(MessageTemplate, CurrentDataSourceSynonym);
			
			AddParameters = New Structure;
			AddParameters.Insert("CurrentData"		, CurrentData);
			AddParameters.Insert("EntriesTabName"	, EntriesTabName);
			AddParameters.Insert("AttributesList"	, AllFieldsToRemoveData);
			
			ShowQueryBox(
				New NotifyDescription("DataSourceOnChangeEnding", ThisObject, AddParameters),
				MessageText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataSourceOnChangeEnding(ClosingResult, AdditionalParameters) Export
	
	CurrentData = AdditionalParameters.CurrentData;
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		WorkWithArbitraryParametersClient.ClearTabSectionRow(CurrentData, AdditionalParameters.AttributesList);
		
		For Each Field In AdditionalParameters.AttributesList Do
			WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(
				Object.ElementsSynonyms,
				Field,
				CurrentData.ConnectionKey);
		EndDo;
			
		FieldsStructureEntriesFilters = GetFieldStructureForChecking("EntriesFilters");
		
		Filter = New Structure("EntryConnectionKey", CurrentData.ConnectionKey);
		
		FoundRows = Object.EntriesFilters.FindRows(Filter);
		For Each FilterRow In FoundRows Do
			
			FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
				FilterRow,
				CurrentDataSource,
				"DataSource",
				FieldsStructureEntriesFilters);
				
			For Each Attribute In FieldsToRemoveData Do
				Object.EntriesFilters.Delete(FilterRow);
			EndDo;
			
		EndDo;
		
		FoundRows = Object.EntriesFilters.FindRows(Filter);
		StringFilterPresentation = "";
		
		For Each FilterRow In FoundRows Do
			StringFilterPresentation = StringFilterPresentation 
				+ StrTemplate("%1 %2 %3;",
					FilterRow.ParameterSynonym,
					FilterRow.ConditionPresentation,
					FilterRow.ValuePresentation);
		EndDo;
		
		CurrentData.FilterPresentation = StringFilterPresentation;
		
		FieldsStructureEntriesDefaultAccounts = GetFieldStructureForChecking("EntriesDefaultAccounts");
		FoundRows = Object.EntriesDefaultAccounts.FindRows(Filter);
		For Each FilterRow In FoundRows Do
			
			FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
				FilterRow,
				CurrentDataSource,
				"DataSource",
				FieldsStructureEntriesDefaultAccounts);
				
			For Each Attribute In FieldsToRemoveData Do
				FilterRow[Attribute] = Undefined;
				FilterRow[StrTemplate("%1Synonym", Attribute)] = Undefined;
			EndDo;
			
		EndDo;
		
		CurrentDataSource			= CurrentData.DataSource;
		CurrentDataSourceSynonym	= CurrentData.DataSourceSynonym;
		
		WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(
			Object,
			"DataSource",
			CurrentData.ConnectionKey,
			CurrentDataSourceSynonym);

	Else
		
		CurrentData.DataSource			= CurrentDataSource;
		CurrentData.DataSourceSynonym	= CurrentDataSourceSynonym;
		
		If CurrentData.ConnectionKey = 0 Then
			DriveClientServer.FillConnectionKey(
				Object[AdditionalParameters.EntriesTabName],
				CurrentData,
				"ConnectionKey");
		EndIf;
		
		WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(
			Object,
			"DataSource",
			CurrentData.ConnectionKey,
			CurrentDataSourceSynonym);
		
	EndIf;

EndProcedure

&AtClient
Procedure EntriesFilterPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenFiltersTool("Entries");
	
EndProcedure

&AtClient
Procedure EntriesPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
		
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.Entries.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("FillPeriods"		, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'period'; ru = 'период';pl = 'okres';es_ES = 'período';es_CO = 'período';tr = 'dönem';it = 'periodo';de = 'Zeitraum'"));
	ChoiceFormParameters.Insert("AttributeID"		, "Period");
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Period);
	ChoiceFormParameters.Insert("AggregateFunction"	, CurrentData.PeriodAggregateFunction);
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Period", CurrentData.ConnectionKey));
	
	AttributeSynonym = WorkWithArbitraryParametersClient.GetAttributeSynonym(
		Object.ElementsSynonyms,
		"Period",
		CurrentData.ConnectionKey);
	
	WorkWithArbitraryParametersClient.FillFormulaParameters(
		CurrentData,
		"Period",
		AttributeSynonym,
		ChoiceFormParameters);
		
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Period");
		
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters),
		FormWindowOpeningMode.LockOwnerWindow);
		
EndProcedure

&AtClient
Procedure EntriesCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.Entries.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.Entries");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["Account"] <> Undefined
		And Not GetAccountFlag(CurrentData["Account"], "Currency") Then
		Return;
	EndIf;
	
	IDAdding = "";
	If CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Dr") Then
		IDAdding = "Dr";
	ElsIf CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Cr") Then
		IDAdding = "Cr";
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Currency);
	ChoiceFormParameters.Insert("NameAdding"		, "");
	ChoiceFormParameters.Insert("FillCurrencies"	, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'transaction currency'; ru = 'валюта операции';pl = 'waluta transakcji';es_ES = 'moneda de transacción';es_CO = 'moneda de transacción';tr = 'işlemin para birimi';it = 'valuta transazione';de = 'Transaktionswährung'"));
	ChoiceFormParameters.Insert("IDAdding"			, IDAdding);
	ChoiceFormParameters.Insert("AttributeID"		, "Currency");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Currency", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Currency");
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters),
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesAmountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.Entries.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Amount);
	ChoiceFormParameters.Insert("FillAmounts"		, True);
	ChoiceFormParameters.Insert("FormulaMode"		, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'amount'; ru = 'сумма';pl = 'wartość';es_ES = 'importe';es_CO = 'importe';tr = 'tutar';it = 'importo';de = 'Betrag'"));
	ChoiceFormParameters.Insert("AttributeID"		, "Amount");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Amount", CurrentData.ConnectionKey));
	
	AttributeSynonym = WorkWithArbitraryParametersClient.GetAttributeSynonym(
		Object.ElementsSynonyms,
		"Amount",
		CurrentData.ConnectionKey);
	WorkWithArbitraryParametersClient.FillFormulaParameters(
		CurrentData,
		"Amount",
		AttributeSynonym,
		ChoiceFormParameters);

	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Amount");
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters), 
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesAmountCurStartChoice(Item, ChoiceData, StandardProcessing)
	
	AmountCurStartChoice(StandardProcessing, "Entries", "");
	
EndProcedure

&AtClient
Procedure EntriesQuantityStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.Entries.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.Entries");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["Account"] <> Undefined
		And Not GetAccountFlag(CurrentData["Account"], "UseQuantity") Then
		Return;
	EndIf;
	
	IDAdding = "";
	If CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Dr") Then
		IDAdding = "Dr";
	ElsIf CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Cr") Then
		IDAdding = "Cr";
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Quantity);
	ChoiceFormParameters.Insert("NameAdding"		, "");
	ChoiceFormParameters.Insert("FillAmounts"		, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'quantity'; ru = 'количество';pl = 'ilość';es_ES = 'cantidad';es_CO = 'cantidad';tr = 'miktar';it = 'quantità';de = 'menge'"));
	ChoiceFormParameters.Insert("IDAdding"			, IDAdding);
	ChoiceFormParameters.Insert("AttributeID"		, "Quantity");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Quantity", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Quantity");
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	AccountStartChoice("Entries", "");
	
EndProcedure

&AtClient
Procedure EntriesAccountOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Entries.CurrentData;
	
	DefaultAccountType = CurrentData.DefaultAccountType;
	
	If ValueIsFilled(DefaultAccountType) Then
		
		AccountStartChoice("Entries", "");
		
	Else
		CurrentValue = CurrentData.Account;
		If ValueIsFilled(CurrentValue) Then
			ShowValue( , CurrentValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesBeforeDeleteRow(Item, Cancel)
	
	SelectedRowsIDs = Item.SelectedRows;
	RowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		RowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	For Each TSRow In RowsArray Do
		
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.ElementsSynonyms,
			TSRow.ConnectionKey,
			"ConnectionKey");
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.EntriesFilters,
			TSRow.ConnectionKey,
			"EntryConnectionKey");
		
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.EntriesDefaultAccounts,
			TSRow.ConnectionKey,
			"EntryConnectionKey");
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure EntriesAfterDeleteRow(Item)
	
	RenumerateEntriesTabSection(True);
	SetMovingButtonsEnabled();
	
EndProcedure

&AtClient
Procedure EntriesOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Clone Then
		
		Row = Item.CurrentData;
		Row.EntryLineNumber = Row.EntryLineNumber + 0.01;
		
		Object.Entries.Sort("EntryNumber, EntryLineNumber");
	
		RenumerateSingleEntrieLines(Row.EntryNumber, Row.EntryNumber, New Array); 
		
		WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "Entries", Row);
		
	ElsIf NewRow And Not Clone Then
		
		CurrentData = Items.Entries.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		CurrentCopyingRow = Object.Entries[CurrentEntryLineNumber];
		
		FillPropertyValues(CurrentData, CurrentCopyingRow, "EntryNumber, Mode, DrCr");
		CurrentData.EntryLineNumber = CurrentCopyingRow.EntryLineNumber + 1;
		
		RenumerateEntiesLines(CurrentCopyingRow.EntryNumber);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	Return;
	
EndProcedure

&AtClient
Procedure EntriesDimensionSetStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("Entries", "");
	
EndProcedure

&AtClient
Procedure EntriesDimensionSetOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("Entries", "");
	
EndProcedure

&AtClient
Procedure AddAnalyticalDimensionsToArrayRecursively(AnalyticalDimensionsArray, CurrentData, NameAdding, Count)
	
	If Count > WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber() Then
		Return;
	EndIf;
	
	CurrentDataAnalyticalDimensionsType = CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, Count)];
	
	If ValueIsFilled(CurrentDataAnalyticalDimensionsType) Then
		
		AnalyticalDimensionsName		= StrTemplate("AnalyticalDimensions%1%2", NameAdding, Count);
		AnalyticalDimensionsSynonymName = StrTemplate("%1Synonym", AnalyticalDimensionsName);
		
		AnalyticalDimensionsStructure = New Structure;
		AnalyticalDimensionsStructure.Insert("AnalyticalDimensionType"			, CurrentDataAnalyticalDimensionsType);
		AnalyticalDimensionsStructure.Insert("AnalyticalDimensionValue"			, CurrentData[AnalyticalDimensionsName]);
		AnalyticalDimensionsStructure.Insert("AnalyticalDimensionValueSynonym"	, CurrentData[AnalyticalDimensionsSynonymName]);
		AnalyticalDimensionsStructure.Insert("DrCr"								, GetDrCr(AnalyticalDimensionsName, CurrentData.ConnectionKey));
		
		AnalyticalDimensionsArray.Add(AnalyticalDimensionsStructure);
		
		AddAnalyticalDimensionsToArrayRecursively(AnalyticalDimensionsArray, CurrentData, NameAdding, Count + 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountStartChoice(TabName, NameAdding, ItemName = "", LineNumber = 0, FieldName = "")
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "ChartOfAccounts");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Chart of accounts'; ru = 'План счетов';pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "TypeOfAccounting");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Type of accounting'; ru = 'Тип бухгалтерского учета';pl = 'Typ rachunkowości';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe türü';it = 'Tipo di contabilità';de = 'Typ der Buchhaltung'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	FieldStructure = New Structure;
	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft") Then 
		FieldStructure.Insert("Name"		, "PlanStartDate");
		FieldStructure.Insert("Synonym"		, NStr("en = 'Planned validity period from'; ru = 'Планируемый срок действия с';pl = 'Zaplanowany okres ważności od';es_ES = 'Periodo de validez planificado desde';es_CO = 'Periodo de validez planificado desde';tr = 'Planlanan geçerlilik dönemi başlangıcı';it = 'Periodo di validità pianificato da';de = 'Geplante Gültigkeitsdauer vom'"));
	Else
		FieldStructure.Insert("Name"		, "StartDate");
		FieldStructure.Insert("Synonym"		, NStr("en = 'From'; ru = 'С';pl = 'Od';es_ES = 'Desde';es_CO = 'Desde';tr = 'Başlangıç';it = 'Da';de = 'Von'"));
	EndIf;
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items[TabName].CurrentData;
	
	IDAdding = NameAdding;
	If TabName = "Entries" And CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Dr") Then
		IDAdding = "Dr";
	ElsIf TabName = "Entries" And CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Cr") Then
		IDAdding = "Cr";
	EndIf;
	
	CurrentAccount = CurrentData[StrTemplate("Account%1", NameAdding)];
	
	If NameAdding = "" Then
		DrCr = PredefinedValue("Enum.DebitCredit.EmptyRef");
	Else
		DrCr = PredefinedValue(StrTemplate("Enum.DebitCredit.%1", NameAdding));
	EndIf;
	
	FiltersArray = GetEntriesDefaultAccountsArray(CurrentData.ConnectionKey, DrCr);
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DefaultAccountType"	, CurrentData[StrTemplate("DefaultAccountType%1", NameAdding)]);
	ChoiceFormParameters.Insert("AccountReferenceName"	, CurrentData[StrTemplate("AccountReferenceName%1", NameAdding)]);
	ChoiceFormParameters.Insert("DataSource"			, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"			, Object.DocumentType);
	ChoiceFormParameters.Insert("TypeOfAccounting"		, Object.TypeOfAccounting);
	ChoiceFormParameters.Insert("Company"				, Object.Company);
	ChoiceFormParameters.Insert("ChartOfAccounts"		, Object.ChartOfAccounts);
	ChoiceFormParameters.Insert("CurrentValue"			, CurrentData[StrTemplate("Account%1", NameAdding)]);
	ChoiceFormParameters.Insert("FillAccounts"			, True);
	ChoiceFormParameters.Insert("AttributeName"			, TrimAll(StrTemplate(NStr("en = 'account %1'; ru = 'счет %1';pl = 'konto %1';es_ES = 'cuenta %1';es_CO = 'cuenta %1';tr = 'hesap %1';it = 'conto %1';de = 'Konto %1'"), NameAdding)));
	ChoiceFormParameters.Insert("AttributeID"			, TrimAll(StrTemplate("Account%1", IDAdding)));
	
	ChoiceFormParameters.Insert("ItemName"				, ItemName);
	ChoiceFormParameters.Insert("LineNumber"			, LineNumber);
	ChoiceFormParameters.Insert("FieldName"				, FieldName);
	
	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active") Then
		ChoiceFormParameters.Insert("BeginOfPeriod"	, Object.StartDate);
		ChoiceFormParameters.Insert("EndOfPeriod"	, Object.EndDate);
	Else
		ChoiceFormParameters.Insert("BeginOfPeriod"	, Object.PlanStartDate);
		ChoiceFormParameters.Insert("EndOfPeriod"	, Object.PlanEndDate);
	EndIf;
	
	ChoiceFormParameters.Insert("FiltersArray", FiltersArray);
	
	ChoiceFormParameters.Insert("NameAdding", NameAdding);
	ChoiceFormParameters.Insert("CurrentAnalyticalDimensionsSetValue",
		CurrentData[StrTemplate("AnalyticalDimensionsSet%1", NameAdding)]);
	
	AnalyticalDimensionsArray = New Array;
	AddAnalyticalDimensionsToArrayRecursively(AnalyticalDimensionsArray, CurrentData, NameAdding, 1);
	
	ChoiceFormParameters.Insert("CurrentAnalyticalDimensions", AnalyticalDimensionsArray);
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName"				, StrTemplate("Account%1", NameAdding));
	AddParameters.Insert("NameAdding"				, NameAdding);
	AddParameters.Insert("DefaultAccountTypeName"	, StrTemplate("DefaultAccountType%1", NameAdding));
	AddParameters.Insert("AccountReferenceNameName"	, StrTemplate("AccountReferenceName%1", NameAdding));
	AddParameters.Insert("DrCr"						, DrCr);
		
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ChartsOfAccountsChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesDimensionSetClearing(Item, StandardProcessing)
	
	ClearAnalyticalDimensions("");
	
EndProcedure

&AtClient
Procedure EntriesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If AllowedEditTemplate(CurrentStatus)
		And (Field.Name = "EntriesAnalyticalDimensionsType1"
			Or Field.Name = "EntriesAnalyticalDimensionsType2" 
			Or Field.Name = "EntriesAnalyticalDimensionsType3" 
			Or Field.Name = "EntriesAnalyticalDimensionsType4" 
			Or Field.Name = "EntriesAnalyticalDimensions1Synonym" 
			Or Field.Name = "EntriesAnalyticalDimensions2Synonym" 
			Or Field.Name = "EntriesAnalyticalDimensions3Synonym" 
			Or Field.Name = "EntriesAnalyticalDimensions4Synonym"
			Or Field.Name = "EntriesDimensionSet") Then
		
		ItemName = "";
		LineNumber = 0;
		FieldName = "";
		
		FillItemsForAccountSelection(Field, ItemName, LineNumber, FieldName);
		
		StandardProcessing = False;
		AccountStartChoice("Entries", "", ItemName, LineNumber, FieldName);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillEntries(Command)
	
	FillEntriesProcess("Entries");
	
EndProcedure

&AtClient
Procedure EntriesFilterPresentationClearing(Item, StandardProcessing)
	
	CurrentData = Items.Entries.CurrentData;
	ClearFilters(CurrentData.ConnectionKey);
	CurrentData.FilterPresentation = "";
	
EndProcedure

#EndRegion

#Region EntriesSimpleFormTableItemsEventHandlers

&AtClient
Procedure EntriesSimpleFilterPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenFiltersTool("EntriesSimple");

EndProcedure

&AtClient
Procedure EntriesSimpleOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		NewEntryParameters = GetNewEntryParameters();
		
		Row = Item.CurrentData;
		Row.Debit	= NewEntryParameters.Dr;
		Row.Credit	= NewEntryParameters.Cr;
		Row.Mode	= NewEntryParameters.Mode;
		
	ElsIf NewRow And Clone Then
		
		WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "EntriesSimple", Item.CurrentData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesSimpleDataSourceStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DocumentType"	 , Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"	 , CurrentData.DataSource);
	ChoiceFormParameters.Insert("FillDataSources", True);
	ChoiceFormParameters.Insert("AttributeName"	 , NStr("en = 'data source'; ru = 'источник данных';pl = 'źródło danych';es_ES = 'fuente de datos';es_CO = 'fuente de datos';tr = 'veri kaynağı';it = 'fonte dati';de = 'Datenquelle'"));
	ChoiceFormParameters.Insert("AttributeID"	 , "DataSource");
	
	CurrentDataSource		 = CurrentData.DataSource;
	CurrentDataSourceSynonym = CurrentData.DataSourceSynonym;
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "DataSource");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesSimpleCurrencyCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountCrSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.EntriesSimple");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["AccountCr"] <> Undefined
		And Not GetAccountFlag(CurrentData["AccountCr"], "Currency") Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.CurrencyCr);
	ChoiceFormParameters.Insert("NameAdding"		, "Cr");
	ChoiceFormParameters.Insert("FillCurrencies"	, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'transaction currency'; ru = 'валюта операции';pl = 'waluta transakcji';es_ES = 'moneda de transacción';es_CO = 'moneda de transacción';tr = 'işlemin para birimi';it = 'valuta transazione';de = 'Transaktionswährung'"));
	ChoiceFormParameters.Insert("AttributeID"		, "Currency");
	ChoiceFormParameters.Insert("IDAdding"			, "Cr");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("CurrencyCr", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "CurrencyCr");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesSimpleCurrencyDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountDrSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.EntriesSimple");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["AccountDr"] <> Undefined
		And Not GetAccountFlag(CurrentData["AccountDr"], "Currency") Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.CurrencyDr);
	ChoiceFormParameters.Insert("NameAdding"		, "Dr");
	ChoiceFormParameters.Insert("FillCurrencies"	, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'transaction currency'; ru = 'валюта операции';pl = 'waluta transakcji';es_ES = 'moneda de transacción';es_CO = 'moneda de transacción';tr = 'işlemin para birimi';it = 'valuta transazione';de = 'Transaktionswährung'"));
	ChoiceFormParameters.Insert("AttributeID"		, "Currency");
	ChoiceFormParameters.Insert("IDAdding"			, "Dr");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("CurrencyDr", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "CurrencyDr");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesSimpleAmountCurDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	AmountCurStartChoice(StandardProcessing, "EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleAmountCurCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	AmountCurStartChoice(StandardProcessing, "EntriesSimple", "Cr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleAmountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Amount);
	ChoiceFormParameters.Insert("FillAmounts"		, True);
	ChoiceFormParameters.Insert("FormulaMode"		, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'amount'; ru = 'сумма';pl = 'wartość';es_ES = 'importe';es_CO = 'importe';tr = 'tutar';it = 'importo';de = 'Betrag'"));
	ChoiceFormParameters.Insert("AttributeID"		, "Amount");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Amount", CurrentData.ConnectionKey));
	
	AttributeSynonym = WorkWithArbitraryParametersClient.GetAttributeSynonym(
		Object.ElementsSynonyms,
		"Amount",
		CurrentData.ConnectionKey);
	WorkWithArbitraryParametersClient.FillFormulaParameters(
		CurrentData,
		"Amount",
		AttributeSynonym,
		ChoiceFormParameters);
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Amount");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesSimpleQuantityDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountDrSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.EntriesSimple");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["AccountDr"] <> Undefined
		And Not GetAccountFlag(CurrentData["AccountDr"], "UseQuantity") Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"	, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"	, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"	, CurrentData.QuantityDr);
	ChoiceFormParameters.Insert("NameAdding"	, "Dr");
	ChoiceFormParameters.Insert("FillAmounts"	, True);
	ChoiceFormParameters.Insert("AttributeName"	, NStr("en = 'quantity'; ru = 'количество';pl = 'ilość';es_ES = 'cantidad';es_CO = 'cantidad';tr = 'miktar';it = 'quantità';de = 'menge'"));
	ChoiceFormParameters.Insert("IDAdding"		, "Dr");
	ChoiceFormParameters.Insert("AttributeID"	, "Quantity");
	ChoiceFormParameters.Insert("DrCr"			, GetDrCr("QuantityDr", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "QuantityDr");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesSimpleQuantityCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AccountCrSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"));
	FieldStructure.Insert("ObjectName"	, "Object.EntriesSimple");
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData["AccountCr"] <> Undefined
		And Not GetAccountFlag(CurrentData["AccountCr"], "UseQuantity") Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"	, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"	, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"	, CurrentData.QuantityCr);
	ChoiceFormParameters.Insert("NameAdding"	, "Cr");
	ChoiceFormParameters.Insert("FillAmounts"	, True);
	ChoiceFormParameters.Insert("AttributeName"	, NStr("en = 'quantity'; ru = 'количество';pl = 'ilość';es_ES = 'cantidad';es_CO = 'cantidad';tr = 'miktar';it = 'quantità';de = 'Menge'"));
	ChoiceFormParameters.Insert("AttributeID"	, "Quantity");
	ChoiceFormParameters.Insert("IDAdding"		, "Cr");
	ChoiceFormParameters.Insert("DrCr"			, GetDrCr("QuantityCr", CurrentData.ConnectionKey));
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "QuantityCr");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure EntriesSimplePeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
		
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"		, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"		, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"		, CurrentData.Period);
	ChoiceFormParameters.Insert("FillPeriods"		, True);
	ChoiceFormParameters.Insert("FormulaMode"		, True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'period'; ru = 'период';pl = 'okres';es_ES = 'período';es_CO = 'período';tr = 'dönem';it = 'periodo';de = 'Zeitraum'"));
	ChoiceFormParameters.Insert("AggregateFunction"	, CurrentData.PeriodAggregateFunction);
	ChoiceFormParameters.Insert("AttributeID"		, "Period");
	ChoiceFormParameters.Insert("DrCr"				, GetDrCr("Period", CurrentData.ConnectionKey));
	
	AttributeSynonym = WorkWithArbitraryParametersClient.GetAttributeSynonym(
		Object.ElementsSynonyms,
		"Period",
		CurrentData.ConnectionKey);
	WorkWithArbitraryParametersClient.FillFormulaParameters(
		CurrentData,
		"Period",
		AttributeSynonym,
		ChoiceFormParameters);
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "Period");
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure EntriesSimpleAccountCrStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
		
	AccountStartChoice("EntriesSimple", "Cr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleAccountDrStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	
	AccountStartChoice("EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleAccountDrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	DefaultAccountType = CurrentData.DefaultAccountTypeDr;
	
	If ValueIsFilled(DefaultAccountType) Then
		AccountStartChoice("EntriesSimple", "Dr");
	Else
		CurrentValue = CurrentData.AccountDr;
		If ValueIsFilled(CurrentValue) Then
			ShowValue( , CurrentValue);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure EntriesSimpleAccountCrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.EntriesSimple.CurrentData;
	
	DefaultAccountType = CurrentData.DefaultAccountTypeCr;
	
	If ValueIsFilled(DefaultAccountType) Then
		AccountStartChoice("EntriesSimple", "Cr");
	Else
		CurrentValue = CurrentData.AccountCr;
		If ValueIsFilled(CurrentValue) Then
			ShowValue( , CurrentValue);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure EntriesSimpleBeforeDeleteRow(Item, Cancel)
	
	SelectedRowsIDs = Item.SelectedRows;
	RowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		RowsArray.Add(Object.EntriesSimple.FindByID(SelectedRowID));
	EndDo;
	
	For Each TSRow In RowsArray Do
		
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.ElementsSynonyms,
			TSRow.ConnectionKey,
			"ConnectionKey");
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.EntriesFilters,
			TSRow.ConnectionKey,
			"EntryConnectionKey");
			
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.EntriesDefaultAccounts,
			TSRow.ConnectionKey,
			"EntryConnectionKey");
			
	EndDo;

EndProcedure

&AtClient
Function GetDrCr(DataFieldName, ConnectionKey)
	
	Filter = New Structure;
	Filter.Insert("MetadataName"	, DataFieldName);
	Filter.Insert("ConnectionKey"	, ConnectionKey);
	
	FilteredRows = Object.ElementsSynonyms.FindRows(Filter);
	
	Result = Undefined;
	If FilteredRows.Count() > 0 Then
		Result = FilteredRows[0].DrCr;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure EntriesSimpleDimensionSetDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetDrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("EntriesSimple", "Cr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetCrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	AccountStartChoice("EntriesSimple", "Cr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetDrClearing(Item, StandardProcessing)
	
	ClearAnalyticalDimensions("Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetCrClearing(Item, StandardProcessing)
	
	ClearAnalyticalDimensions("Cr");
	
EndProcedure

&AtClient
Procedure FillEntriesSimple(Command)
	
	FillEntriesProcess("EntriesSimple");
	
EndProcedure

&AtClient
Procedure EntriesSimpleFilterPresentationClearing(Item, StandardProcessing)
	
	CurrentData = Items.EntriesSimple.CurrentData;
	ClearFilters(CurrentData.ConnectionKey);
	CurrentData.FilterPresentation = "";
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddEntry(Command)
	
	NewEntryParameters = GetNewEntryParameters();
	EntryNumber = GetNextEntryNumber();
	
	DrLine = Object.Entries.Add();
	DrLine.EntryNumber		= EntryNumber;
	DrLine.EntryLineNumber	= 1;
	DrLine.Mode				= NewEntryParameters.Mode;
	DrLine.DrCr				= NewEntryParameters.Dr;
	DrLine.NumberPresentation = StrTemplate("%1/%2", EntryNumber, 1);
	
	CrLine = Object.Entries.Add();
	CrLine.EntryNumber		= EntryNumber;
	CrLine.EntryLineNumber	= 2;
	CrLine.Mode				= NewEntryParameters.Mode;
	CrLine.DrCr				= NewEntryParameters.Cr;
	CrLine.NumberPresentation = StrTemplate("%1/%2", EntryNumber, 2);

	SetMovingButtonsEnabled();
	
	CurrentRowLineNumber	 = DrLine.GetID();
	Items.Entries.CurrentRow = CurrentRowLineNumber;
	
EndProcedure

&AtClient
Procedure AddEntryLine(Command)
	
	CurrentData = Items.Entries.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentIndex	= Object.Entries.IndexOf(CurrentData);
	NewLine			= Object.Entries.Insert(CurrentIndex + 1);
	
	FillPropertyValues(NewLine, CurrentData, "EntryNumber, Mode, DrCr");
	NewLine.EntryLineNumber = CurrentData.EntryLineNumber + 1;
	
	RenumerateEntiesLines(CurrentData.EntryNumber);
	
	Items.Entries.CurrentRow = NewLine.GetID();
	
EndProcedure

&AtClient
Procedure EntriesUp(Command)
	
	SelectedRowsIDs = Items.Entries.SelectedRows;
	RowsArray = New Array;
	
	SortedSelectedRowsIDs = SortSelectedRowsArray(SelectedRowsIDs);
	
	For Each SelectedRowID In SortedSelectedRowsIDs Do
		RowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	CheckResult = CheckRowsInOneEntry(RowsArray);
	
	If CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.Property("ConsecutiveEntries") 
		And CheckResult.WholeEntry 
		And CheckResult.ConsecutiveEntries 
		And RowsArray.Count() > 1 Then
		
		MoveSeveralEntries(RowsArray, -1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
		
	ElsIf CheckResult.Property("SeveralEntries") 
		Or CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() > 1 Then
		
		MessageText = NStr("en = 'Cannot move the selected lines of accounting entries. 
			|Select a single line or all lines of one accounting entry. 
			|Then try again.'; 
			|ru = 'Не удалось переместить выбранные строки бухгалтерских проводок. 
			|Выберите одну строку или все строки одной бухгалтерской проводки и повторите попытку.';
			|pl = 'Nie można przenieść wybranych wierszy wpisów księgowych. 
			|Wybierz oddzielny wiersz lub wszystkie wiersze jednego wpisu księgowego. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırları taşınamıyor. 
			| 1 muhasebe girişinin tek bir satırını veya
			| tüm satırlarını seçip tekrar deneyin.';
			|it = 'Impossibile spostare le righe selezionate delle voci di contabilità. 
			|Selezionare una singola riga o tutte le righe di una voce di contabilità
			|, poi riprovare.';
			|de = 'Fehler beim Verschieben von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie eine einzelne Zeile oder alle Zeilen einer Buchung aus. 
			|Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		MoveEntry(RowsArray, -1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
	
	ElsIf CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() = 1 Then
		
		MoveRows(RowsArray, -1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
			
	Else
		Return;
	EndIf;
	
	Modified = True;

EndProcedure

&AtClient
Procedure EntriesDown(Command)
	
	SelectedRowsIDs = Items.Entries.SelectedRows;
	RowsArray = New Array;
	
	SortedSelectedRowsIDs = SortSelectedRowsArray(SelectedRowsIDs);
	
	For Each SelectedRowID In SortedSelectedRowsIDs Do
		RowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	CheckResult = CheckRowsInOneEntry(RowsArray);
	
	If CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.Property("ConsecutiveEntries") 
		And CheckResult.WholeEntry 
		And CheckResult.ConsecutiveEntries 
		And RowsArray.Count() > 1 Then
		
		MoveSeveralEntries(RowsArray, 1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
		Modified = True;
		
	ElsIf CheckResult.Property("SeveralEntries") 
		Or CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() > 1 Then
		
		MessageText = NStr("en = 'Cannot move the selected lines of accounting entries. 
			|Select a single line or all lines of the one accounting entry. 
			|Then try again.'; 
			|ru = 'Не удалось переместить выбранные строки бухгалтерских проводок. 
			|Выберите одну строку или все строки одной бухгалтерской проводки и повторите попытку.';
			|pl = 'Nie można przenieść wybranych wierszy wpisów księgowych. 
			|Wybierz oddzielny wiersz lub wszystkie wiersze jednego wpisu księgowego. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırları taşınamıyor. 
			| 1 muhasebe girişinin tek bir satırını veya
			| tüm satırlarını seçip tekrar deneyin.';
			|it = 'Impossibile spostare le righe selezionare delle voci di contabilità.
			|Selezionare una riga singola o tutte le righe della singola voce di contabilità,
			| poi riprovare.';
			|de = 'Fehler beim Verschieben von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie eine einzelne Zeile oder alle Zeilen der Buchung aus. 
			|Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		MoveEntry(RowsArray, 1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
	
	ElsIf CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() = 1 Then
		
		MoveRows(RowsArray, 1);
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
	
	Else
		Return;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CopyEntriesRows(Command)
	
	SelectedRowsIDs = Items.Entries.SelectedRows;
	RowsArray = New Array;
	
	SortedSelectedRowsIDs = SortSelectedRowsArray(SelectedRowsIDs);
	
	For Each SelectedRowID In SortedSelectedRowsIDs Do
		RowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	CheckResult = CheckRowsInOneEntry(RowsArray);
	
	If CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And Not CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		MessageText = NStr("en = 'Cannot copy the selected lines of accounting entries. 
			|Select a single line or all lines of one accounting entry. 
			|Then try again.'; 
			|ru = 'Не удалось скопировать выбранные строки бухгалтерских проводок. 
			|Выберите одну строку или все строки одной бухгалтерской проводки и повторите попытку.';
			|pl = 'Nie można skopiować wybranych wierszy wpisów księgowych. 
			|Wybierz oddzielny wiersz lub wszystkie wiersze jednego wpisu księgowego. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırları kopyalanamıyor. 
			| 1 muhasebe girişinin tek bir satırını veya
			| tüm satırlarını seçip tekrar deneyin.';
			|it = 'Impossibile copiare le righe selezionate delle voci di contabilità.
			|Selezionare una singola riga o tutte le righe della singola voce di contabilità, 
			| poi riprovare.';
			|de = 'Fehler beim Kopieren von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie eine einzelne Zeile oder alle Zeilen einer Buchung aus. 
			|Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("WholeEntry") 
		And Not CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		MessageText = NStr("en = 'Cannot copy the selected lines of accounting entries. 
			|Select a single line or all lines of the one accounting entry. 
			|Then try again.'; 
			|ru = 'Не удалось скопировать выбранные строки бухгалтерских проводок. 
			|Выберите одну строку или все строки одной бухгалтерской проводки и повторите попытку.
			|';
			|pl = 'Nie można skopiować wybranych wierszy wpisów księgowych. 
			|Wybierz oddzielny wiersz lub wszystkie wiersze jednego wpisu księgowego. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden mover las líneas seleccionadas de entradas contables. 
			|Seleccione una sola línea o todas las líneas de una entrada contable. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırları kopyalanamıyor. 
			| 1 muhasebe girişinin tek bir satırını veya
			| tüm satırlarını seçip tekrar deneyin.';
			|it = 'Impossibile copiare le righe selezionate delle voci di contabilità.
			| Selezionare una riga o tutte le righe della singola voce di contabilità, 
			|poi riprovare.';
			|de = 'Fehler beim Kopieren von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie eine einzelne Zeile oder alle Zeilen der Buchung aus. 
			|Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.Property("ConsecutiveEntries") 
		And CheckResult.WholeEntry 
		And Not CheckResult.ConsecutiveEntries 
		And RowsArray.Count() > 1 Then
		
		MessageText = NStr("en = 'Cannot copy the selected lines of accounting entries. 
			|Select consecutive lines of accounting entries. 
			|Then try again.'; 
			|ru = 'Не удалось скопировать выбранные строки бухгалтерских проводок. 
			|Выберите последовательные строки бухгалтерских проводок и повторите попытку.';
			|pl = 'Nie można skopiować wybranych wierszy wpisów księgowych. 
			|Wybierz kolejne wiersze wpisów ksiągowych. 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se pueden mover las líneas seleccionadas de entradas contables.
			|Seleccione líneas consecutivas de entradas contables. 
			|Inténtelo de nuevo.';
			|es_CO = 'No se pueden mover las líneas seleccionadas de entradas contables.
			|Seleccione líneas consecutivas de entradas contables. 
			|Inténtelo de nuevo.';
			|tr = 'Seçilen muhasebe girişi satırları kopyalanamıyor. 
			|Ardışık muhasebe girişi satırları seçip
			|tekrar deneyin.';
			|it = 'Impossibile copiare le righe selezionate delle voci di contabilità.
			|Selezionare righe consecutive di voci di contabilità,
			| poi riprovare.';
			|de = 'Fehler beim Kopieren von ausgewählten Zeilen von Buchungen. 
			|Wählen Sie konsequente Zeilen von Buchungen aus. 
			|Dann versuchen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		CurrentRowLineNumber = Undefined;
		CurrentEntryNumber = RowsArray[0].EntryNumber;
		EntryNumber = 0;
		For Each RowToCopy In RowsArray Do
			
			EntryNumber = ?(CurrentEntryNumber = RowToCopy.EntryNumber, EntryNumber, EntryNumber + 0.01);
			
			NewLine = Object.Entries.Add();
			FillPropertyValues(NewLine, RowToCopy, , "EntryNumber");
			NewLine.EntryNumber = EntryNumber;
			
			CurrentRowLineNumber = ?(CurrentRowLineNumber = Undefined, NewLine.GetID(), CurrentRowLineNumber);
		
			WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "Entries", NewLine);
			
			CurrentEntryNumber = RowToCopy.EntryNumber;
		
		EndDo;
		
		RenumerateEntriesTabSection();
		Items.Entries.CurrentRow = CurrentRowLineNumber;
		Modified = True;
		
	ElsIf RowsArray.Count() = 1 And CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		NewEntryParameters = GetNewEntryParameters();
		EntryNumber = GetNextEntryNumber();
		
		NewLine = Object.Entries.Add();
		
		RowToCopy = RowsArray[0];
		FillPropertyValues(NewLine, RowToCopy);
		
		NewLine.EntryNumber			= EntryNumber;
		NewLine.EntryLineNumber		= 1;
		NewLine.NumberPresentation	= StrTemplate("%1/%2", EntryNumber, 1);
		
		CurrentRowLineNumber	 = NewLine.GetID();
		Items.Entries.CurrentRow = CurrentRowLineNumber;
		
		WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "Entries", NewLine);

		Modified = True;
		
	ElsIf RowsArray.Count() = 1 And CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry Then
		
		RowToCopy	= RowsArray[0];
		NewLine		= Object.Entries.Add();
		
		FillPropertyValues(NewLine, RowToCopy);
		
		RenumerateEntiesLines(NewLine.EntryNumber, True);
		
		WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "Entries", NewLine);
		
		CurrentRowLineNumber	 = NewLine.GetID();
		Items.Entries.CurrentRow = CurrentRowLineNumber;
		
		Modified = True;
			
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		CurrentRowLineNumber = Undefined;
		
		For Each RowToCopy In RowsArray Do
			
			NewLine = Object.Entries.Add();
			FillPropertyValues(NewLine, RowToCopy, , "EntryNumber");
			
			CurrentRowLineNumber = ?(CurrentRowLineNumber = Undefined, NewLine.GetID(), CurrentRowLineNumber);
		
			WorkWithArbitraryParametersClient.CopyRowProcessing(Object, "Entries", NewLine);
			
		EndDo;
		
		RenumerateEntriesTabSection();
		Items.Entries.CurrentRow = CurrentRowLineNumber;
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SortSelectedRowsArray(SelectedRowsIDs) 
	
	SelectedRowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		SelectedRowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	TempEntries = Object.Entries.Unload(SelectedRowsArray);
	TempEntries.Sort("EntryNumber, EntryLineNumber");
	
	SelectedRowsArray.Clear();
	
	Filter = New Structure("EntryNumber, EntryLineNumber");
		
	For Each Row In TempEntries Do
		
		RowByFilter = Object.Entries[Row.LineNumber - 1];
		SelectedRowsArray.Add(RowByFilter.GetID());
		
	EndDo;
	
	Return SelectedRowsArray;
	
EndFunction

&AtServer
Function FilterToolParameters(TableName, RowID)

	CurRowData = Object[TableName].FindByID(RowID);
	If CurRowData.ConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object[TableName], CurRowData, "ConnectionKey");
	EndIf;

	CurrentRowFilterStructure = New Structure("EntryConnectionKey", CurRowData.ConnectionKey);
	CurrentEntryFilters = Object.EntriesFilters.Unload(CurrentRowFilterStructure);
	
	AddressInTemporaryStorage = PutToTempStorage(CurrentEntryFilters, ThisObject.UUID);

	FilterToolParametersStructure = New Structure;
	FilterToolParametersStructure.Insert("AddressInTemporaryStorage", AddressInTemporaryStorage);
	FilterToolParametersStructure.Insert("DocumentType"				, Object.DocumentType); 
	FilterToolParametersStructure.Insert("OwnerFormUUID"			, ThisObject.UUID);
	FilterToolParametersStructure.Insert("ConnectionKey"			, CurRowData.ConnectionKey);
	FilterToolParametersStructure.Insert("DataSource"				, CurRowData.DataSource);
	
	Return FilterToolParametersStructure;

EndFunction 

&AtClient
Procedure SetStatusPeriodVisibility()

	Items.GroupActiveDates.Visible = Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active");
	Items.PlanDates.Visible = Not Items.GroupActiveDates.Visible;
		
	If ValueIsFilled(Object.Ref) And Object.Status <> CurrentStatus Then
		
		Items.WarningSaveStatus.Visible = True;
		Items.DecorationStatus.Title = StrTemplate(NStr("en = 'To apply the %1 status, save the template.'; ru = 'Для применения статуса %1 нужно сохранить шаблон.';pl = 'Aby zastosować status %1, zapisz szablon.';es_ES = 'Para aplicar el estado %1, guarda la plantilla.';es_CO = 'Para aplicar el estado %1, guarda la plantilla.';tr = '%1 durumunu uygulamak için şablonu kaydedin.';it = 'Per applicare lo stato %1, salvare il modello.';de = 'Speichern Sie die Vorlage, um den Status %1 zu verwenden.'"), Object.Status);
	Else
		Items.WarningSaveStatus.Visible = False;
	EndIf;

EndProcedure

&AtClient
Procedure SetDates()
	
	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active") Then
		
		Object.EndDate	 = Object.PlanEndDate;
		Object.StartDate = Object.PlanStartDate;
		
		CurrentEndDate	 = Object.EndDate;
		CurrentStartDate = Object.StartDate;
		
		Object.PlanEndDate	 = Undefined;
		Object.PlanStartDate = Undefined;
		
		CurrentPlanEndDate	 = Undefined;
		CurrentPlanStartDate = Undefined;
		
	ElsIf Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft") Then
		
		Object.PlanEndDate	 = Object.EndDate;
		Object.PlanStartDate = Object.StartDate;
		
		CurrentPlanEndDate	 = Object.PlanEndDate;
		CurrentPlanStartDate = Object.PlanStartDate;
		
		Object.EndDate	 = Undefined;
		Object.StartDate = Undefined;
		
		CurrentEndDate	 = Undefined;
		CurrentStartDate = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEntriesTabVisibility()
	
	AvailableStructure = WorkWithArbitraryParametersServerCall.GetChartsOfAccountsData(Object.ChartOfAccounts);
	
	UseExtDimension	= AvailableStructure.UseAnalyticalDimensions;
	UseQuantity		= AvailableStructure.UseQuantity;
	
	If IsComplexTypeOfEntries Then
		
		Items.EntriesSimplePage.Visible		= False;
		Items.EntriesCompoundPage.Visible	= True;
		
		Items.EntriesDimensionSet.Visible				= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions1.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions2.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions3.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions4.Visible	= UseExtDimension;
		
		Items.EntriesQuantity.Visible = UseQuantity;
		
	Else
		
		Items.EntriesSimplePage.Visible		= True;
		Items.EntriesCompoundPage.Visible	= False;
		
		Items.EntriesSimpleGroupDimensionsSet.Visible			= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions1.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions2.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions3.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions4.Visible	= UseExtDimension;
		
		Items.EntriesSimpleGroupQty.Visible = UseQuantity;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetMovingButtonsEnabled()

	Items.EntriesGroupUpDown.Enabled = (Object.Entries.Count() <> 0);

EndProcedure

&AtClient
Procedure OpenFiltersTool(TableName)

	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray) Then
		Return;
	EndIf;
	
	CurrentDataIdentifier	= Items[TableName].CurrentData.GetID();
	ParametersOfFilterTool	= FilterToolParameters(TableName, CurrentDataIdentifier);
		
	OpenForm("Catalog.AccountingEntriesTemplates.Form.FilterEditingTool",
		ParametersOfFilterTool,
		ThisObject,
		,
		,
		,
		,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AttributesChoiceEnding(ClosingResult, AdditionalParameters) Export

	Var FieldName; 
	
	If TypeOf(ClosingResult) <> Type("Structure")
		Or TypeOf(AdditionalParameters) <> Type("Structure") 
		Or Not AdditionalParameters.Property("FieldName", FieldName) Then
		
		Return;
		
	EndIf;
	
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	CurrentData = Items[EntriesTabName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.ConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object[EntriesTabName], CurrentData, "ConnectionKey");
	EndIf;
	
	If ClosingResult.Property("DefaultAccount") Then
		CurrentData[AdditionalParameters.FieldName]				= ClosingResult.Field;
		CurrentData[AdditionalParameters.FieldName + "Synonym"] = ClosingResult.Synonym;
		
		CurrentData[AdditionalParameters.DefaultAccountTypeName]	= ClosingResult.DefaultAccountType;
		CurrentData[AdditionalParameters.AccountReferenceNameName]	= ClosingResult.AccountReferenceName;
		
		FillEntriesDefaultAccounts(CurrentData.ConnectionKey, AdditionalParameters.DrCr, ClosingResult.FiltersArray);
		
		AddParameters = New Structure;
		AddParameters.Insert("FieldName", StrTemplate("AnalyticalDimensionsSet%1", AdditionalParameters.NameAdding));
		AttributesChoiceEnding(ClosingResult.AnalyticalDimensions, AddParameters);
		
	ElsIf ClosingResult.Property("NameAdding")
		And AdditionalParameters.FieldName = StrTemplate("AnalyticalDimensionsSet%1", ClosingResult.NameAdding) Then
		
		CurrentData[AdditionalParameters.FieldName] = ClosingResult.Field;
		
		ClearAnalyticalDimensions(ClosingResult.NameAdding);
		
		Count = 1;
		For Each Item In ClosingResult.AnalyticalDimensions Do
			
			ItemTypeFieldName	 = StrTemplate("AnalyticalDimensionsType%1%2", ClosingResult.NameAdding, Count);
			ItemFieldName		 = StrTemplate("AnalyticalDimensions%1%2", ClosingResult.NameAdding, Count);
			
			CurrentData[ItemTypeFieldName]			 = Item.AnalyticalDimensionType;
			CurrentData[ItemFieldName]				 = Item.AnalyticalDimensionValue;
			CurrentData[ItemFieldName + "Synonym"]	 = Item.AnalyticalDimensionValueSynonym;
			
			Count = Count + 1;
			
			WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(
				Object,
				ItemFieldName,
				CurrentData.ConnectionKey,
				Item.AnalyticalDimensionValueSynonym,
				Item.DrCr);
			
		EndDo;
		
	Else
		
		If AdditionalParameters.Property("DrCr") Then
			ClearEntriesDefaultAccounts(CurrentData.ConnectionKey, AdditionalParameters.DrCr);
		EndIf;
		
		CurrentData[AdditionalParameters.FieldName]				= ClosingResult.Field;
		CurrentData[AdditionalParameters.FieldName + "Synonym"] = ClosingResult.Synonym;
		
		If AdditionalParameters.Property("DefaultAccountTypeName") Then
			CurrentData[AdditionalParameters.DefaultAccountTypeName]	= ClosingResult.DefaultAccountType;
			CurrentData[AdditionalParameters.AccountReferenceNameName]	= ClosingResult.AccountReferenceName;
		EndIf;
		
		If AdditionalParameters.FieldName = "Account"
			Or AdditionalParameters.FieldName = "AccountDr"
			Or AdditionalParameters.FieldName = "AccountCr" Then
			
			NameAdding = StrReplace(AdditionalParameters.FieldName, "Account", "");
			
			FieldsStructure = New Structure;
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)1", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)2", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)3", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)4", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)1", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)2", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)3", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)4", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsSet%1", NameAdding));
			FieldsStructure.Insert(StrTemplate("Quantity%1"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("Currency%1"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("AmountCur%1", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)1Synonym", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)2Synonym", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)3Synonym", NameAdding));
			FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)4Synonym", NameAdding));
			FieldsStructure.Insert(StrTemplate("Quantity%1Synonym"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("Currency%1Synonym"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("AmountCur%1Synonym"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("DefaultAccountType%1"	, NameAdding));
			FieldsStructure.Insert(StrTemplate("AccountReferenceName%1"	, NameAdding));
			FieldsStructure.Insert("ConnectionKey");
			FillPropertyValues(FieldsStructure, CurrentData);
			
			UpdateAccountReferenceFields(FieldsStructure, ClosingResult.Field, AdditionalParameters.DrCr, NameAdding);
			
			FillPropertyValues(CurrentData, FieldsStructure);
			
			AddParameters = New Structure;
			AddParameters.Insert("FieldName", StrTemplate("AnalyticalDimensionsSet%1", AdditionalParameters.NameAdding));
			AttributesChoiceEnding(ClosingResult.AnalyticalDimensions, AddParameters);
			
		EndIf;
		
	EndIf;
		
	WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(
		Object,
		AdditionalParameters.FieldName,
		CurrentData.ConnectionKey,
		ClosingResult.Synonym,
		ClosingResult.DrCr);
	
	If FieldName = "DataSource" Then
		EntriesDataSourceOnChange(Undefined);
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillEntriesDefaultAccounts(ConnectionKey, DrCr, FiltersArray)
	
	SearchStructure = New Structure("EntryConnectionKey, DrCr", ConnectionKey, DrCr);
	FoundRows = Object.EntriesDefaultAccounts.FindRows(SearchStructure);
	
	IsEqual = FoundRows.Count() = FiltersArray.Count();
	If IsEqual Then
		
		For i = 0 To FiltersArray.Count() - 1 Do
			
			OldRow = FoundRows[i];
			NewRow = FiltersArray[i];
			For Each Column In FiltersArray[0] Do
				
				ColumnKey = Column.Key;
				If ColumnKey = "SavedValueType" Then
					Continue;
				ElsIf ColumnKey = "LineNumber" Then
					ColumnKey = "EntryOrder";
				ElsIf ColumnKey = "TypeDescription" Then
					ColumnKey = "ValueType";
				EndIf;
				
				IsEqual = NewRow[Column.Key] = OldRow[ColumnKey];
				
				If Not IsEqual Then
					Break;
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	If Not IsEqual Then
		
		ClearEntriesDefaultAccounts(ConnectionKey, DrCr);
		
		For Each FilterRow In FiltersArray Do
			NewRow = Object.EntriesDefaultAccounts.Add();
			FillPropertyValues(NewRow, FilterRow, , "DrCr");
			
			NewRow.EntryOrder			= FilterRow.LineNumber;
			NewRow.ValueType			= FilterRow.TypeDescription;
			NewRow.EntryConnectionKey	= ConnectionKey;
			NewRow.DrCr					= DrCr;
			NewRow.FilterDrCr			= FilterRow.DrCr;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ClearEntriesDefaultAccounts(ConnectionKey, DrCr)
	
	SearchStructure = New Structure("EntryConnectionKey,DrCr", ConnectionKey, DrCr);
	
	FoundRows = Object.EntriesDefaultAccounts.FindRows(SearchStructure);
	
	For Each Row In FoundRows Do 
		RowIndex = Object.EntriesDefaultAccounts.IndexOf(Row);
		Object.EntriesDefaultAccounts.Delete(RowIndex);
	EndDo;
	
EndProcedure

&AtServer
Function GetEntriesDefaultAccountsArray(ConnectionKey, DrCr)
	
	FiltersArray = New Array;
	
	SearchStructure = New Structure("EntryConnectionKey,DrCr", ConnectionKey, DrCr);
	
	FoundRows = Object.EntriesDefaultAccounts.FindRows(SearchStructure);
	
	For Each Row In FoundRows Do 
		
		RowStructure = New Structure("LineNumber, FilterName, FilterSynonym, Value, ValueSynonym, TypeDescription");
		FillPropertyValues(RowStructure, Row);
		
		RowStructure.Insert("DrCr", Row.FilterDrCr);
		
		RowStructure.LineNumber		 = Row.EntryOrder; 
		RowStructure.TypeDescription = Row.ValueType; 
		
		FiltersArray.Add(RowStructure);
		
	EndDo;
	
	Return FiltersArray;
	
EndFunction

&AtClient
Procedure ClearingSynonymTable(Item, StandardProcessing)

	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	CurrentData = Items[EntriesTabName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentDataSource			= CurrentData.DataSource;
	CurrentDataSourceSynonym	= CurrentData.DataSourceSynonym;
	
	FieldName = StrReplace(Item.Name, EntriesTabName, "");
	CurrentData[FieldName] = Undefined;
	
	If FieldName = "Account"
		Or FieldName = "AccountDr"
		Or FieldName = "AccountCr" Then
		
		NameAdding = StrReplace(FieldName, "Account", "");
		
		FieldsStructure = New Structure;
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)1", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)2", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)3", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)4", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)1", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)2", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)3", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsType%(1)4", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensionsSet%1", NameAdding));
		FieldsStructure.Insert(StrTemplate("Quantity%1"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("Currency%1"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("AmountCur%1", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)1Synonym", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)2Synonym", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)3Synonym", NameAdding));
		FieldsStructure.Insert(StrTemplate("AnalyticalDimensions%(1)4Synonym", NameAdding));
		FieldsStructure.Insert(StrTemplate("Quantity%1Synonym"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("Currency%1Synonym"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("AmountCur%1Synonym"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("DefaultAccountType%1"	, NameAdding));
		FieldsStructure.Insert(StrTemplate("AccountReferenceName%1"	, NameAdding));
		FieldsStructure.Insert("ConnectionKey", CurrentData.ConnectionKey);
		
		UpdateAccountReferenceFields(FieldsStructure, Undefined, Undefined, NameAdding);
		FillPropertyValues(CurrentData, FieldsStructure);
		
	EndIf;
		
	If FieldName <> "DataSource" Then
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ElementsSynonyms, FieldName, CurrentData.ConnectionKey);
	EndIf;

EndProcedure

&AtServer
Procedure SetComplexTypeOfEntries()
	
	IsComplexTypeOfEntries = WorkWithArbitraryParameters.SetComplexTypeOfEntries(Object.ChartOfAccounts, Object.Entries.Count());
	
EndProcedure

&AtServer
Procedure SetRestrictedStatus()

	If Object.Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		SetReadOnlyFormAttributes(False);
	Else
		SetReadOnlyFormAttributes(True);
	EndIf;
		
EndProcedure

&AtServer
Procedure SetReadOnlyFormAttributes(Restriction)

	Items.Company.ReadOnly				= Restriction;
	Items.TypeOfAccounting.ReadOnly		= Restriction;
	Items.ChartOfAccounts.ReadOnly		= Restriction;
	Items.DocumentType.ReadOnly			= Restriction;
	
	Items.ParametersPage.ReadOnly		= Restriction;
	Items.AdditionalInfoPage.ReadOnly	= Restriction;
	
	ArrayExceptions = New Array;
	If Restriction Then
		ArrayExceptions.Add("EntriesNumberPresentation");
		ArrayExceptions.Add("EntriesDimensionSet");
		ArrayExceptions.Add("EntriesAmountContent");
		ArrayExceptions.Add("EntriesSimpleAmountContent");
		ArrayExceptions.Add("EntriesSimpleLineNumber");
		ArrayExceptions.Add("EntriesSimpleGroupDtCr");
	EndIf;
	
	If IsComplexTypeOfEntries Then
		VisibleTables("Entries", ArrayExceptions, Restriction);
	Else
		VisibleTables("EntriesSimple", ArrayExceptions, Restriction);
	EndIf;
	
EndProcedure

&AtServer
Procedure VisibleTables(TableName, ArrayExceptions, Restriction)

	ItemTable = Items[TableName];
	
	If ItemTable.Visible = True Then
		
		ItemTable.ContextMenu.Enabled	= Not Restriction;
		ItemTable.CommandBar.Enabled	= Not Restriction;
		ItemTable.ChangeRowSet			= Not Restriction;
		ItemTable.ChangeRowOrder		= Not Restriction;
		
		ChildTableItems = ItemTable.ChildItems;
		
		For Each CurrentElement In ChildTableItems Do
			
			If ArrayExceptions.Find(CurrentElement.Name) = Undefined  Then
				CurrentElement.ReadOnly = Restriction; 
			EndIf;
			
		EndDo;
		
		Items[TableName + "Amount"].ReadOnly = Restriction;
	EndIf;
	
EndProcedure

&AtServer
Procedure MapTabSections()
	
	CurrentObject = FormAttributeToValue("Object");
	
	Map = New Map;
	Map.Insert("SavedValueType", "ValueType");
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(
		Object.EntriesDefaultAccounts,
		CurrentObject.EntriesDefaultAccounts,
		Map);
	
	Map.Insert("Condition", "ConditionPresentation");
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(
		Object.Parameters,
		CurrentObject.Parameters,
		Map);
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(
		Object.EntriesFilters,
		CurrentObject.EntriesFilters,
		Map);
	
EndProcedure

&AtServer
Procedure CopyDynamicAttributes(CopyingRef)
	
	If Not ValueIsFilled(CopyingRef) Then
		Return;
	EndIf;

	CopyingObject = CopyingRef.GetObject();
	
	Map = New Map;
	Map.Insert("SavedValueType", "ValueType"); 
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(Object.EntriesDefaultAccounts, 
		CopyingObject.EntriesDefaultAccounts, 
		Map);
	
	Map.Insert("Condition", "ConditionPresentation"); 
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(Object.Parameters	, CopyingObject.Parameters, Map);
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(Object.EntriesFilters, CopyingObject.EntriesFilters, Map);

	
EndProcedure 

&AtServer
Procedure SerializeParametersConditions(CurrentObject)
	
	Map = New Map;
	Map.Insert("SavedValueType", "ValueType");
	WorkWithArbitraryParameters.SetTableValueStorageAttributesByMap(
		Object.EntriesDefaultAccounts,
		CurrentObject.EntriesDefaultAccounts,
		Map);
	
	Map.Insert("Condition", "ConditionPresentation"); 
	WorkWithArbitraryParameters.SetTableValueStorageAttributesByMap(Object.Parameters, CurrentObject.Parameters, Map);
	WorkWithArbitraryParameters.SetTableValueStorageAttributesByMap(Object.EntriesFilters, CurrentObject.EntriesFilters, Map);
	
EndProcedure

&AtServer
Procedure InitSimpleEntries()
	
	For Each Row In Object.EntriesSimple Do
		Row.Debit	= Enums.DebitCredit.Dr;
		Row.Credit	= Enums.DebitCredit.Cr;
	EndDo;
	
EndProcedure

&AtServer
Procedure InitSynonyms()
	
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	SynonymTS = Object.ElementsSynonyms;
	
	For Each Row In Object[EntriesTabName] Do
		
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "DataSource"			, "DataSourceSynonym");
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Amount"				, "AmountSynonym");
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Period"				, "PeriodSynonym");
		
		If EntriesTabName = "EntriesSimple" Then
			
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AccountCr"					, "AccountCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AccountDr"					, "AccountDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "CurrencyDr"				, "CurrencyDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "CurrencyCr"				, "CurrencyCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "QuantityCr"				, "QuantityCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "QuantityDr"				, "QuantityDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCurDr"				, "AmountCurDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCurCr"				, "AmountCurCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr1"	, "AnalyticalDimensionsDr1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr2"	, "AnalyticalDimensionsDr2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr3"	, "AnalyticalDimensionsDr3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr4"	, "AnalyticalDimensionsDr4Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr1"	, "AnalyticalDimensionsCr1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr2"	, "AnalyticalDimensionsCr2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr3"	, "AnalyticalDimensionsCr3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr4"	, "AnalyticalDimensionsCr4Synonym");
			
		ElsIf EntriesTabName = "Entries" Then
			
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Account"				, "AccountSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Currency"				, "CurrencySynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Quantity"				, "QuantitySynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCur"				, "AmountCurSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions1"	, "AnalyticalDimensions1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions2"	, "AnalyticalDimensions2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions3"	, "AnalyticalDimensions3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions4"	, "AnalyticalDimensions4Synonym");
			
		EndIf;
	EndDo;

EndProcedure

&AtServer
Function GetEntriesFiltersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	TableForImport = GetFromTempStorage(AddressInTemporaryStorage);
	
	// Clear old versions
	ClearFilters(RowKey);
	
	// Generate presentation for filter line
	StringFilterPresentation = "";
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.EntriesFilters.Add();
		
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.EntryConnectionKey = RowKey;
		
		StringFilterPresentation = StringFilterPresentation 
			+ StrTemplate("%1 %2 %3;",
				ImportRow.ParameterSynonym,
				ImportRow.ConditionPresentation,
				ImportRow.ValuePresentation);
				
	EndDo;
	
	ConnectionKeyFilter	= New Structure("ConnectionKey", RowKey);
	
	CurrentEntryRow = Object[EntriesTabName].FindRows(ConnectionKeyFilter);
	If CurrentEntryRow.Count() > 0 Then
		CurrentEntryRow[0].FilterPresentation = StringFilterPresentation;
	EndIf;
	
EndFunction

#Region EntryTabNumbering

&AtClient
Function GetNextEntryNumber()
	
	MaxEntryIndex = 0;
	
	For Each Row In Object.Entries Do
		If Row.EntryNumber > MaxEntryIndex Then
			MaxEntryIndex = Row.EntryNumber;
		EndIf;
	EndDo;
	
	Return MaxEntryIndex + 1;
	
EndFunction 

&AtClient
Procedure RenumerateEntiesLines(EntryNumber, Sort = False)
	
	If Sort Then
		Object.Entries.Sort("EntryNumber, EntryLineNumber");
	EndIf;
	
	EntriesLineIndex = 1;
	
	For Each Row In Object.Entries Do
		If Row.EntryNumber = EntryNumber Then
			
			Row.EntryLineNumber = EntriesLineIndex;
			EntriesLineIndex = EntriesLineIndex + 1;
			
			SetRowNumberPresentation(Row);
			
		EndIf;
	EndDo; 
	
EndProcedure

&AtClient
Procedure RenumerateEntriesTabSection(Sort = False)
	
	If Sort Then
		Object.Entries.Sort("EntryNumber, EntryLineNumber");
	EndIf;
	
	EntriesNumbers = GetEntriesNumberAtServer();
	
	EntriesIndex	= 1;
	CalculatedRows	= New Array;
	
	For Each EntriesNumber In EntriesNumbers Do
		
		RenumerateSingleEntrieLines(EntriesNumber, EntriesIndex, CalculatedRows);
		
		EntriesIndex = EntriesIndex + 1;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RenumerateSingleEntrieLines(CurrentEntriesNumber, NewEntriesNumber, CalculatedRowsArray)
	
	CurrentEntryLines = GetEntriesLines(CurrentEntriesNumber);
	
	EntryLineIndex = 1;
	
	For Each EntryLine In CurrentEntryLines Do
		
		If CalculatedRowsArray.Find(EntryLine) <> Undefined Then 
			Continue;
		EndIf;
		
		EntryLine.EntryNumber		= NewEntriesNumber;
		EntryLine.EntryLineNumber	= EntryLineIndex;
		
		EntryLineIndex = EntryLineIndex + 1;
		CalculatedRowsArray.Add(EntryLine);
		
		SetRowNumberPresentation(EntryLine);
	EndDo;
	
EndProcedure

&AtClient
Function GetEntriesLines(EntriesNumber)
	
	CurrentEntryFilter	= New Structure("EntryNumber", EntriesNumber);
	CurrentEntryLines	= Object.Entries.FindRows(CurrentEntryFilter);
	
	Return CurrentEntryLines;
	
EndFunction

&AtClient
Function GetMaxEntryLineIndex(EntriesNumber)
	
	EntriesLines		= GetEntriesLines(EntriesNumber);
	EntriesLinesCount	= EntriesLines.Count();
	
	Return EntriesLinesCount;
	
EndFunction

&AtClient
Procedure SetRowNumberPresentation(TSrow)

	If IsComplexTypeOfEntries Then
		TSRow.NumberPresentation = StrTemplate("%1/%2", TSrow.EntryNumber, TSrow.EntryLineNumber);
	Else
		TSRow.NumberPresentation = TSrow.EntryNumber;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTSNumberPresentations()

	For Each Row In Object.Entries Do
		If IsComplexTypeOfEntries Then
			Row.NumberPresentation = StrTemplate("%1/%2", Row.EntryNumber, Row.EntryLineNumber);
		Else
			Row.NumberPresentation = Row.EntryNumber;
		EndIf;
	EndDo;

EndProcedure

&AtClient
Procedure MoveEntry(RowsArray, Direction)

	For Each Row In RowsArray Do
		Row.EntryNumber = Row.EntryNumber + 1.1 * Direction;
	EndDo;
	
	RenumerateEntriesTabSection(True);
	
EndProcedure

&AtClient
Procedure MoveSeveralEntries(RowsArray, Direction)
	
	SelectedRowsIDs = New Array;
	For Each Row In RowsArray Do
		SelectedRowsIDs.Add(Row.GetID());
	EndDo;
	
	CountOfSelectedEntryLines = GetCountOfSelectedEntryLines(SelectedRowsIDs);
	
	Multiplier = CountOfSelectedEntryLines + 0.1;
	
	EntriesNumbers = GetEntriesNumberAtServer();
	
	FirstEntryNumber	= RowsArray[0].EntryNumber;
	LastEntryNumber		= RowsArray[RowsArray.UBound()].EntryNumber;
	CalculatedRowsArray	= New Array;
	
	For Each Row In RowsArray Do
		
		If CalculatedRowsArray.Find(Row.EntryNumber) <> Undefined Then 
			Continue;
		EndIf;
		
		EntriesArray	= GetEntriesLines(Row.EntryNumber);
		IsFirstEntry	= Row.EntryNumber = FirstEntryNumber;
		IsLastEntry		= Row.EntryNumber = LastEntryNumber;
		
		For Each EntryRow In EntriesArray Do
			
			EntryRow.EntryNumber = EntryRow.EntryNumber + Multiplier * Direction;
			
			If IsFirstEntry And Direction < 0 
				Or IsLastEntry And Direction > 0 Then
				
				EntryRow.EntryNumber = EntryRow.EntryNumber - 0.2 * Direction;
				
			EndIf;
			
		EndDo;
		
		CalculatedRowsArray.Add(Row.EntryNumber);
		
	EndDo;
	
	RenumerateEntriesTabSection(True);
	
EndProcedure

&AtServer
Function GetCountOfSelectedEntryLines(SelectedRowsIDs) 
	
	SelectedRowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		SelectedRowsArray.Add(Object.Entries.FindByID(SelectedRowID));
	EndDo;
	
	TempEntries = Object.Entries.Unload(SelectedRowsArray);
	TempEntries.GroupBy("EntryNumber");
	CountOfSelectedEntryLines = TempEntries.UnloadColumn("EntryNumber").Count();
	
	Return CountOfSelectedEntryLines;
	
EndFunction

&AtClient
Procedure MoveRows(RowsArray, Direction)
	
	MaxEntryNumber			= Object.Entries[Object.Entries.Count() - 1].EntryNumber;
	PreviousEntryNumber		= Min(Max(RowsArray[0].EntryNumber + Direction, 1), MaxEntryNumber);	// Previous could be actually next
	PrevEntriesLines		= GetEntriesLines(PreviousEntryNumber);
	PrevEntriesLinesCount	= PrevEntriesLines.Count();
	LastRowIndex			= Object.Entries.Count();
	RowsCount				= RowsArray.Count();
	
	MaxEntryLineIndex = ?(PrevEntriesLinesCount > 0, PrevEntriesLines[PrevEntriesLinesCount - 1].EntryLineNumber, 0);
	
	For Each Row In RowsArray Do
		
		RowIndex = Object.Entries.IndexOf(Row);
		FirstLineEntry	= (Row.EntryLineNumber = 1 Or Row.DrCr <> Object.Entries[RowIndex - 1].DrCr);
		LastLineEntry	= (Row.EntryLineNumber = GetMaxEntryLineIndex(Row.EntryNumber) Or Row.DrCr <> Object.Entries[RowIndex + 1].DrCr);
		BorderEntry		= (Row.EntryNumber = PreviousEntryNumber);
		
		SwitchEntryUp	= (FirstLineEntry And Direction < 0);
		SwitchEntryDown = (LastLineEntry And Direction > 0);
		
		If SwitchEntryUp And Not BorderEntry Then
			
			Row.EntryNumber		= PreviousEntryNumber;
			Row.EntryLineNumber	= MaxEntryLineIndex + 1;
			
		ElsIf SwitchEntryDown And Not BorderEntry Then
			
			Row.EntryNumber		= PreviousEntryNumber;
			Row.EntryLineNumber	= 0.01;
			
		ElsIf Not SwitchEntryUp And Not SwitchEntryDown Then
			Row.EntryLineNumber = Row.EntryLineNumber + (RowsCount + 0.01) * Direction;
		EndIf;
		
	EndDo;
	
	RenumerateEntriesTabSection(True);
	
EndProcedure

&AtClient
Function CheckRowsInOneEntry(RowsArray)

	EntryNumbersMap	= New Map;
	ReturnStructure	= New Structure;
	
	For Each TSRow In RowsArray Do
		
		NewValue = ?(EntryNumbersMap.Get(TSRow.EntryNumber) = Undefined, 1, EntryNumbersMap.Get(TSRow.EntryNumber)+1);
		EntryNumbersMap.Insert(TSRow.EntryNumber, NewValue);
		
	EndDo;
	
	WholeEntry = True;
	FirstEntryLine = Undefined;
	For Each MapItem In EntryNumbersMap Do
		
		EntryNumberFilter	= New Structure("EntryNumber", MapItem.Key);
		EntriesLines		= Object.Entries.FindRows(EntryNumberFilter);
		WholeEntry			= WholeEntry And EntriesLines.Count() = MapItem.Value;
		
		If FirstEntryLine = Undefined Then
			ConsecutiveEntries = True;
		ElsIf MapItem.Key = FirstEntryLine + 1 Then
			ConsecutiveEntries = ConsecutiveEntries And True;
		Else
			ConsecutiveEntries = False;
		EndIf;
		
		FirstEntryLine = MapItem.Key;
		
	EndDo;
	
	ReturnStructure.Insert("WholeEntry" , WholeEntry);
	
	If EntryNumbersMap.Count() = 1 Then
		ReturnStructure.Insert("EntryNumber", MapItem.Key);
	ElsIf EntryNumbersMap.Count() > 1 Then
		ReturnStructure.Insert("SeveralEntries", True);
		ReturnStructure.Insert("ConsecutiveEntries", ConsecutiveEntries);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

&AtServer
Function GetEntriesNumberAtServer()

	EntriesNumberVT = Object.Entries.Unload( , "EntryNumber");
	EntriesNumberVT.GroupBy("EntryNumber");
	
	Return EntriesNumberVT.UnloadColumn("EntryNumber");

EndFunction 

&AtServerNoContext
Function GetNewEntryParameters()

	ParametersStructure = New Structure;
	ParametersStructure.Insert("Mode", Enums.AccountingEntriesDataSourceModes.Separate);
	ParametersStructure.Insert("Dr", Enums.DebitCredit.Dr);
	ParametersStructure.Insert("Cr", Enums.DebitCredit.Cr);

	Return ParametersStructure;
	
EndFunction 

#EndRegion

&AtClient
Procedure ClearingTemplateRequestEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.No Then
		SubordinateTemplatesCheckInProgress = False;
		Return;
	EndIf;
	
	// Yes - save element
	SaveElementWithSubordinateTemplatesClearing();
	
	If FormClosing Then
		Close();
	EndIf;
	
	SetTSNumberPresentations();
	SetStatusPeriodVisibility();
	
EndProcedure

&AtServer
Procedure SaveElementWithSubordinateTemplatesClearing()
	
	CurrentObject = FormAttributeToValue("Object");
	CurrentObject.AdditionalProperties.Insert("SubordinateTemplatesClearing", True);
	CurrentObject.AdditionalProperties.Insert("SubordinateTemplatesChecked", True);
	
	CurrentObject.Write();
	
	SubordinateTemplatesCheckInProgress = False;
	Modified = False;
	Read();
	
EndProcedure

&AtServer
Function CheckSubordinateTemplates()
	
	ReturnStructure = Catalogs.AccountingEntriesTemplates.CheckSubordinateTemplates(Object);
	
	CatalogObject = FormAttributeToValue("Object");
	ModifiedAttributes = DriveServer.GetModifiedAttributes(CatalogObject);
	
	ReturnStructure.Insert("ModifiedContent", ModifiedAttributes.Count() = 1
		And (ModifiedAttributes[0] = "EntriesSimple.Content" Or ModifiedAttributes[0] = "Entries.Content"));

	Return ReturnStructure;
	
EndFunction

&AtClient
Procedure ClearAnalyticalDimensions(FieldName)

	If FieldName = "" Then
		CurrentData = Items.Entries.CurrentData;
	Else
		CurrentData = Items.EntriesSimple.CurrentData;
	EndIf;
	
	MaxAnalyticalDimensionsNumber = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	For Index = 1 To MaxAnalyticalDimensionsNumber Do
		
		ItemTypeFieldName	= "AnalyticalDimensionsType"	+ FieldName + Index;
		ItemFieldName		= "AnalyticalDimensions"		+ FieldName + Index;
		
		CurrentData[ItemTypeFieldName]			= Undefined;
		CurrentData[ItemFieldName]				= Undefined;
		CurrentData[ItemFieldName + "Synonym"]	= Undefined;
		
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ElementsSynonyms, ItemFieldName, CurrentData.ConnectionKey);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure EntriesSimpleSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If AllowedEditTemplate(CurrentStatus) Then
		
		ItemName = "";
		LineNumber = 0;
		FieldName = "";
		
		FillItemsForAccountSelection(Field, ItemName, LineNumber, FieldName);
		
		If Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr1"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr2"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr3"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr4"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsDr1Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsDr2Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsDr3Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsDr4Synonym"
			Or Field.Name = "EntriesSimpleDimensionSetDr" Then
			
			StandardProcessing = False;
			AccountStartChoice("EntriesSimple", "Dr", ItemName, LineNumber, FieldName);
		
		ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr1"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr2"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr3"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr4"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr1Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr2Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr3Synonym"
			Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr4Synonym"
			Or Field.Name = "EntriesSimpleDimensionSetCr" Then
		
			StandardProcessing = False;
			AccountStartChoice("EntriesSimple", "Cr", ItemName, LineNumber, FieldName);
		
		EndIf;
	EndIf;
EndProcedure

&AtServerNoContext
Function AllowedEditTemplate(Status)
	
	Return Status <> Enums.AccountingEntriesTemplatesStatuses.Active;
	
EndFunction

&AtClient
Procedure PlanStartDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanEndDate) And Object.PlanStartDate > Object.PlanEndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodPlannedDateFromErrorText();
		
		Object.PlanStartDate = CurrentPlanStartDate;
		
		CommonClientServer.MessageToUser(MessageText, , "Object.PlanStartDate");
		
	Else
		CurrentPlanStartDate = Object.PlanStartDate;
		WorkWithArbitraryParametersClient.CheckAccountsValueValidation(Object, Object.PlanStartDate, Object.PlanEndDate);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PlanEndDateOnChange(Item)

	If ValueIsFilled(Object.PlanStartDate) 
		And ValueIsFilled(Object.PlanEndDate)
		And Object.PlanStartDate > Object.PlanEndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodPlannedDateTillErrorText();
		
		Object.PlanEndDate = CurrentPlanEndDate;
		
		CommonClientServer.MessageToUser(MessageText, , "Object.PlanEndDate");
		
	Else
		CurrentPlanEndDate = Object.PlanEndDate;
		WorkWithArbitraryParametersClient.CheckAccountsValueValidation(Object, Object.PlanStartDate, Object.PlanEndDate);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	If ValueIsFilled(Object.EndDate) And Object.StartDate > Object.EndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodDateFromErrorText();
		
		Object.StartDate = CurrentStartDate;
		
		CommonClientServer.MessageToUser(MessageText, , "Object.StartDate");
		
	Else
		CurrentStartDate = Object.StartDate;
		WorkWithArbitraryParametersClient.CheckAccountsValueValidation(Object, Object.StartDate, Object.EndDate);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)

	If ValueIsFilled(Object.StartDate) 
		And ValueIsFilled(Object.EndDate)
		And Object.StartDate > Object.EndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodDateTillErrorText();
		
		Object.EndDate = CurrentEndDate;
		
		CommonClientServer.MessageToUser(MessageText, , "StartDate", "Object.EndDate");
		
	Else
		CurrentEndDate = Object.EndDate;
		WorkWithArbitraryParametersClient.CheckAccountsValueValidation(Object, Object.StartDate, Object.EndDate);
	EndIf;
EndProcedure

&AtClient
Procedure DocumentTypeClearing(Item, StandardProcessing)
	Object.DocumentType = Undefined;
EndProcedure

&AtServer
Function GetAccountFlag(Account, FlagName)

	If (TypeOf(Account) = Type("CatalogRef.DefaultAccounts") 
		Or TypeOf(Account) = Type("ChartOfAccountsRef.MasterChartOfAccounts"))
		And ValueIsFilled(Account) Then
		
		Return Common.ObjectAttributeValue(Account, FlagName);
		
	Else
		Return False;
	EndIf;

EndFunction

&AtClient
Procedure CompanyOnChange(Item)
	
	If CurrentCompany <> Object.Company Then
		WorkWithArbitraryParametersClient.CheckAccountsValidation(Object);
	EndIf;
	
	CurrentCompany = Object.Company;
	
EndProcedure

&AtClient
Procedure TypeOfAccountingOnChange(Item)
	
	If CurrentTypeOfAccounting <> Object.TypeOfAccounting Then
		WorkWithArbitraryParametersClient.CheckAccountsValidation(Object);
		UpdateDescription(CurrentTypeOfAccounting, Object.TypeOfAccounting);
		CurrentTypeOfAccounting	 = Object.TypeOfAccounting;
	EndIf;
	
EndProcedure

&AtServer
Function CheckDocumentTypeForChartOfAccounts()
	
	AttributesTable = WorkWithArbitraryParameters.InitParametersTable();
	WorkWithArbitraryParameters.GetRecordersListByCoA(AttributesTable, Object.ChartOfAccounts);
	
	FoundRows = AttributesTable.FindRows(New Structure("Field", Object.DocumentType));
	
	Return FoundRows.Count() > 0;
	
EndFunction

&AtClient
Procedure ChartOfAccountsOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.ChartOfAccounts = CurrentChartOfAccounts;
		SetComplexTypeOfEntries();
		Return;
		
	ElsIf Result = DialogReturnCode.Yes And AdditionalParameters.Property("DocumentType") Then
		
		FieldStructure = GetFieldStructureForChecking();
		
		FieldsToRemove = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
			Object,
			GetDocumentTypeName(CurrentDocumentType),
			"DocumentType",
			FieldStructure);
		
		ClosingResult = New Structure;
		
		ClosingResult.Insert("Field", PredefinedValue("Catalog.MetadataObjectIDs.EmptyRef"));
		ClosingResult.Insert("Synonym", "");
		ClosingResult.Insert("ValueType", New TypeDescription);
		
		AddParameters = New Structure;
		AddParameters.Insert("ClosingResult", ClosingResult);
		AddParameters.Insert("AttributesList", FieldsToRemove);
		
		DocumentTypeChoiceEnding(DialogReturnCode.Yes, AddParameters);
		
		PrevComplexTypeOfEntries = IsComplexTypeOfEntries;
		
		SetComplexTypeOfEntries();
		
		If PrevComplexTypeOfEntries <> IsComplexTypeOfEntries 
			And (Object.Entries.Count() > 0 Or Object.EntriesSimple.Count() > 0) Then
			
			AddParameters = New Structure;
			AddParameters.Insert("ClearEntries", True);
			AddParameters.Insert("PrevComplexTypeOfEntries", PrevComplexTypeOfEntries);
			
			ChartOfAccountsOnChangeEnd(DialogReturnCode.Yes, AddParameters);
			
			Return;
		EndIf;
		
	ElsIf Result = DialogReturnCode.Yes And AdditionalParameters.Property("ClearEntries") Then
		
		WorkWithArbitraryParametersClient.ClearObjectEntries(AdditionalParameters.PrevComplexTypeOfEntries, Object);
		Object.EntriesDefaultAccounts.Clear();
		
	Else
		
		PrevComplexTypeOfEntries = IsComplexTypeOfEntries;
		
		SetComplexTypeOfEntries();
		
		If PrevComplexTypeOfEntries <> IsComplexTypeOfEntries 
			And (Object.Entries.Count() > 0 Or Object.EntriesSimple.Count() > 0) Then
			
			NewTypeOfEntries = GetTypeOfEntries(Object.ChartOfAccounts);
			
			CurrentTypeOfEntries = GetTypeOfEntries(CurrentChartOfAccounts);
			
			QueryTemplate = NStr("en = 'For %1, the type of entries is ""%2"". It does not match the type of entries ""%3"" on the Entries tab. The Entries tab will be cleared. Continue?'; ru = 'Для %1 указан тип проводок ""%2"". Он не соответствует типу проводок ""%3"" на вкладке ""Проводки"". Вкладка ""Проводки"" будет очищена. Продолжить?';pl = 'Dla %1, typ wpisu to ""%2"". On nie jest zgodny z typem wpisów ""%3"" na karcie Wpisy. Karta Wpisy zostanie wyczyszczona. Kkontynuować?';es_ES = 'Para %1, el tipo de entradas es ""%2"". No coincide con el tipo de entradas ""%3"" en la pestaña Entradas. La pestaña de Entradas se eliminará. ¿Continuar?';es_CO = 'Para %1, el tipo de entradas es ""%2"". No coincide con el tipo de entradas ""%3"" en la pestaña Entradas. La pestaña de Entradas se eliminará. ¿Continuar?';tr = '%1 için, giriş türü ""%2"". Bu tür, Girişler sekmesindeki ""%3"" giriş türü ile eşleşmiyor. Girişler sekmesi temizlenecek. Devam edilsin mi?';it = 'Per %1, il tipo di voci è ""%2"". Non corrisponde al tipo di voci ""%3"" nella scheda Voci. La scheda Voci sarà cancellata, continuare?';de = 'Für %1, ist der Typ von Buchungen ""%2"". Er stimmt mit dem Typ von Buchungen ""%3"" auf der Registerkarte Buchungen nicht überein. Die Registerkarte Buchungen wird gelöscht. Weiter?'");
			
			QueryText = StrTemplate(QueryTemplate, 
				Object.ChartOfAccounts,
				NewTypeOfEntries,
				CurrentTypeOfEntries);
			
			AddParameters = New Structure;
			AddParameters.Insert("ClearEntries", True);
			AddParameters.Insert("PrevComplexTypeOfEntries", PrevComplexTypeOfEntries);
			
			ShowQueryBox(
				New NotifyDescription("ChartOfAccountsOnChangeEnd", ThisObject, AddParameters),
				QueryText,
				QuestionDialogMode.YesNo,
				0);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	SetEntriesTabVisibility();
	
	WorkWithArbitraryParametersClient.CheckAccountsValidation(Object, "ChartOfAccounts");
	UpdateDescription(CurrentChartOfAccounts, Object.ChartOfAccounts);
	CurrentChartOfAccounts = Object.ChartOfAccounts;
	
EndProcedure

&AtServerNoContext
Function GetTypeOfEntries(ChartOfAccounts)
	SimpleTypeOfEntries = PredefinedValue("Enum.ChartsOfAccountsTypesOfEntries.Simple");
	
	If ValueIsFilled(ChartOfAccounts) Then
		TypeOfEntries = Common.ObjectAttributeValue(ChartOfAccounts, "TypeOfEntries");
	Else
		TypeOfEntries = SimpleTypeOfEntries;
	EndIf;
	
	Return TypeOfEntries;
EndFunction

&AtServer
Procedure UpdateDescription(OldData, NewData)
	
	If Not ValueIsFilled(OldData) Then
		Object.Description = StrTemplate("%1: %2 (%3)", ?(ValueIsFilled(Object.DocumentType), Object.DocumentType.Synonym, ""), Object.TypeOfAccounting, Object.ChartOfAccounts);
	ElsIf TypeOf(OldData) = Type("CatalogRef.MetadataObjectIDs")
		Or TypeOf(OldData) = Type("CatalogRef.ExtensionObjectIDs") Then
		
		NewDataSynonym = "";
		If ValueIsFilled(NewData) Then
			NewDataSynonym = NewData.Synonym;
		EndIf;
		Object.Description = StrReplace(Object.Description, OldData.Synonym, NewDataSynonym);
		
	Else
		Object.Description = StrReplace(Object.Description, OldData, NewData);
	EndIf;
	
EndProcedure

&AtClient
Function GetFieldStructureForChecking(DataType = "Document")
	
	Result = New Structure;
	
	If DataType = "Document"
		Or DataType = "Parameters" Then
		
		ParametersArray = New Array;
		ParametersArray.Add("ParameterName");
		
		If DataType = "Parameters" Then
			Result.Insert("Row", ParametersArray);
		Else
			Result.Insert("Parameters", ParametersArray);
		EndIf;
		
	EndIf;
	
	If DataType = "Document"
		Or DataType = "Entries" Then
		
		EntriesArray = New Array;
		EntriesArray.Add("DataSource");
		EntriesArray.Add("Account");
		EntriesArray.Add("Period");
		EntriesArray.Add("AnalyticalDimensions1");
		EntriesArray.Add("AnalyticalDimensions2");
		EntriesArray.Add("AnalyticalDimensions3");
		EntriesArray.Add("AnalyticalDimensions4");
		EntriesArray.Add("Currency");
		EntriesArray.Add("Quantity");
		EntriesArray.Add("Amount");
		EntriesArray.Add("AmountCur");
		
		If DataType = "Entries" Then
			Result.Insert("Row", EntriesArray);
		Else
			Result.Insert("Entries", EntriesArray);
		EndIf;
		
	EndIf;
	
	If DataType = "Document"
		Or DataType = "EntriesSimple" Then
		
		EntriesSimpleArray = New Array;
		EntriesSimpleArray.Add("DataSource");
		EntriesSimpleArray.Add("Period");
		EntriesSimpleArray.Add("Amount");
		EntriesSimpleArray.Add("AccountCr");
		EntriesSimpleArray.Add("AccountDr");
		EntriesSimpleArray.Add("AmountCurDr");
		EntriesSimpleArray.Add("AmountCurCr");
		EntriesSimpleArray.Add("CurrencyCr");
		EntriesSimpleArray.Add("CurrencyDr");
		EntriesSimpleArray.Add("AnalyticalDimensionsCr1");
		EntriesSimpleArray.Add("AnalyticalDimensionsCr2");
		EntriesSimpleArray.Add("AnalyticalDimensionsCr3");
		EntriesSimpleArray.Add("AnalyticalDimensionsCr4");
		EntriesSimpleArray.Add("AnalyticalDimensionsDr1");
		EntriesSimpleArray.Add("AnalyticalDimensionsDr2");
		EntriesSimpleArray.Add("AnalyticalDimensionsDr3");
		EntriesSimpleArray.Add("AnalyticalDimensionsDr4");
		EntriesSimpleArray.Add("QuantityCr");
		EntriesSimpleArray.Add("QuantityDr");
		
		If DataType = "EntriesSimple" Then
			Result.Insert("Row", EntriesSimpleArray);
		Else
			Result.Insert("EntriesSimple", EntriesSimpleArray);
		EndIf;
		
	EndIf;
	
	If DataType = "Document"
		Or DataType = "EntriesFilters" Then
		
		EntriesFiltersArray = New Array;
		EntriesFiltersArray.Add("ParameterName");
		
		If DataType = "EntriesFilters" Then
			Result.Insert("Row", EntriesFiltersArray);
		Else
			Result.Insert("EntriesFilters", EntriesFiltersArray);
		EndIf;
		
	EndIf;
	
	If DataType = "Document"
		Or DataType = "EntriesDefaultAccounts" Then
		
		EntriesDefaultAccountsArray = New Array;
		EntriesDefaultAccountsArray.Add("Value");
		
		If DataType = "EntriesDefaultAccounts" Then
			Result.Insert("Row", EntriesDefaultAccountsArray);
		Else
			Result.Insert("EntriesDefaultAccounts", EntriesDefaultAccountsArray);
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function GetDocumentTypeName(DocumentType)
	
	DocMetadata = Common.MetadataObjectByID(DocumentType);
	Return DocMetadata.Name;
	
EndFunction

&AtClient
Procedure EntriesDrCrStartChoice(Item, ChoiceData, StandardProcessing)
	CurrentDrCr = Items.Entries.CurrentData.DrCr;
EndProcedure

&AtClient
Procedure EntriesDrCrOnChange(Item)
	
	If CurrentDrCr <> Items.Entries.CurrentData.DrCr Then
		Object.Entries.Sort("EntryNumber, DrCr Desc");
		RenumerateEntriesTabSection(False);
	EndIf;
	
EndProcedure

&AtServer
Function CheckEntriesAtServer(FieldsToFill)
	
	ObjectFields = New Array;
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	
	FieldsAreFilled = False;
	For Each Row In Object.Entries Do
		
		For Each Field In FieldsToFill Do
			
			FieldName = Field.Name;
			
			If FieldName = "DimensionValue" Then
				
				For i = 1 To MaxAnalyticalDimensionsNumber Do
					
					If ValueIsFilled(Row["AnalyticalDimensionsType" + i]) Then
						
						FieldName = "AnalyticalDimensions" + i;
						
						NewRow = New Structure;
						NewRow.Insert("DataSource"		, Row.DataSource);
						NewRow.Insert("Row"				, Object.Entries.IndexOf(Row));
						NewRow.Insert("Field"			, FieldName);
						NewRow.Insert("Synonym"			, StrTemplate(NStr("en = 'Analytical dimensions %1'; ru = 'Аналитические измерения %1';pl = 'Wymiary analityczne %1';es_ES = 'Dimensiones analíticas %1';es_CO = 'Dimensiones analíticas %1';tr = 'Analitik boyutlar %1';it = 'Dimensioni analitiche %1';de = 'Analytische Messungen %1'"), i));
						NewRow.Insert("CheckType"		, Field.CheckType);
						NewRow.Insert("DrCr"			, Row.DrCr);
						NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName]));
						NewRow.Insert("Value"			, Row[FieldName]);
						NewRow.Insert("ValueSynonym"	, Row[FieldName + "Synonym"]);
						NewRow.Insert("TypeDescription"	, Row["AnalyticalDimensionsType" + i].ValueType);
						
						ObjectFields.Add(NewRow);
						
						FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
						
					EndIf;
					
				EndDo;
				
			Else
				
				NewRow = New Structure;
				NewRow.Insert("DataSource"		, Row.DataSource);
				NewRow.Insert("Row"				, Object.Entries.IndexOf(Row));
				NewRow.Insert("Field"			, FieldName);
				NewRow.Insert("Synonym"			, Field.Synonym);
				NewRow.Insert("CheckType"		, Field.CheckType);
				NewRow.Insert("DrCr"			, Row.DrCr);
				NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName]));
				NewRow.Insert("Value"			, Row[FieldName]);
				NewRow.Insert("ValueSynonym"	, Row[FieldName + "Synonym"]);
				NewRow.Insert("TypeDescription"	, Field.Type);
				
				ObjectFields.Add(NewRow);
				
				FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	For Each Row In Object.EntriesSimple Do
		
		For Each Field In FieldsToFill Do
			
			FieldName = Field.Name;
			
			If FieldName = "DimensionValue" Then
				
				For i = 1 To MaxAnalyticalDimensionsNumber Do
					
					If ValueIsFilled(Row["AnalyticalDimensionsTypeDr" + i]) Then
						
						FieldName = "AnalyticalDimensionsDr" + i;
						
						NewRow = New Structure;
						NewRow.Insert("DataSource"		, Row.DataSource);
						NewRow.Insert("Row"				, Object.EntriesSimple.IndexOf(Row));
						NewRow.Insert("Field"			, FieldName);
						NewRow.Insert("Synonym"			, StrTemplate(NStr("en = 'Analytical dimensions %1(Dr)'; ru = 'Аналитические измерения %1(Дт)';pl = 'Wymiary analityczne %1(Wn)';es_ES = 'Dimensiones analíticas %1 (Dr)';es_CO = 'Dimensiones analíticas %1 (Dr)';tr = 'Analitik boyutlar %1(Borç)';it = 'Dimensioni analitiche %1 (deb)';de = 'Analytische Messungen %1(Soll)'"), i));
						NewRow.Insert("CheckType"		, Field.CheckType);
						NewRow.Insert("DrCr"			, Enums.DebitCredit.Dr);
						NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName]));
						NewRow.Insert("Value"			, Row[FieldName]);
						NewRow.Insert("ValueSynonym"	, Row[FieldName + "Synonym"]);
						NewRow.Insert("TypeDescription"	, Row["AnalyticalDimensionsTypeDr" + i].ValueType);
						
						ObjectFields.Add(NewRow);
						
						FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
						
					EndIf;
					
				EndDo;
				
				For i = 1 To MaxAnalyticalDimensionsNumber Do
					
					If ValueIsFilled(Row["AnalyticalDimensionsTypeCr" + i]) Then
						
						FieldName = "AnalyticalDimensionsCr" + i;
						
						NewRow = New Structure;
						NewRow.Insert("DataSource"		, Row.DataSource);
						NewRow.Insert("Row"				, Object.EntriesSimple.IndexOf(Row));
						NewRow.Insert("Field"			, FieldName);
						NewRow.Insert("Synonym"			, StrTemplate(NStr("en = 'Analytical dimensions %1(Cr)'; ru = 'Аналитические измерения %1(Кт)';pl = 'Wymiary analityczne %1(Ma)';es_ES = 'Dimensiones analíticas %1(Cr)';es_CO = 'Dimensiones analíticas %1(Cr)';tr = 'Analitik boyutlar %1(Alacak)';it = 'Dimensioni analitiche %1 (cred)';de = 'Analytische Messungen %1 (Haben)'"), i));
						NewRow.Insert("CheckType"		, Field.CheckType);
						NewRow.Insert("DrCr"			, Enums.DebitCredit.Cr);
						NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName]));
						NewRow.Insert("Value"			, Row[FieldName]);
						NewRow.Insert("ValueSynonym"	, Row[FieldName + "Synonym"]);
						NewRow.Insert("TypeDescription"	, Row["AnalyticalDimensionsTypeCr" + i].ValueType);
						
						ObjectFields.Add(NewRow);
						
						FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
						
					EndIf;
					
				EndDo;
				
			ElsIf FieldName = "Currency"
				Or FieldName = "AmountCur"
				Or FieldName = "Quantity" Then
				
				NewRow = New Structure;
				NewRow.Insert("DataSource"		, Row.DataSource);
				NewRow.Insert("Row"				, Object.EntriesSimple.IndexOf(Row));
				NewRow.Insert("Field"			, FieldName + "Dr");
				NewRow.Insert("Synonym"			, Field.Synonym);
				NewRow.Insert("CheckType"		, Field.CheckType);
				NewRow.Insert("DrCr"			, Enums.DebitCredit.Dr);
				NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName + "Dr"]));
				NewRow.Insert("Value"			, Row[FieldName + "Dr"]);
				NewRow.Insert("ValueSynonym"	, Row[FieldName + "Dr" + "Synonym"]);
				NewRow.Insert("TypeDescription"	, Field.Type);
				
				ObjectFields.Add(NewRow);
				
				FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
				
				NewRow = New Structure;
				NewRow.Insert("DataSource"		, Row.DataSource);
				NewRow.Insert("Row"				, Object.EntriesSimple.IndexOf(Row));
				NewRow.Insert("Field"			, FieldName + "Cr");
				NewRow.Insert("Synonym"			, Field.Synonym);
				NewRow.Insert("CheckType"		, Field.CheckType);
				NewRow.Insert("DrCr"			, Enums.DebitCredit.Dr);
				NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName + "Cr"]));
				NewRow.Insert("Value"			, Row[FieldName + "Cr"]);
				NewRow.Insert("ValueSynonym"	, Row[FieldName + "Cr" + "Synonym"]);
				NewRow.Insert("TypeDescription"	, Field.Type);
				
				ObjectFields.Add(NewRow);
				
				FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
				
			Else
				
				NewRow = New Structure;
				NewRow.Insert("DataSource"		, Row.DataSource);
				NewRow.Insert("Row"				, Object.EntriesSimple.IndexOf(Row));
				NewRow.Insert("Field"			, FieldName);
				NewRow.Insert("Synonym"			, Field.Synonym);
				NewRow.Insert("CheckType"		, Field.CheckType);
				NewRow.Insert("DrCr"			, "");
				NewRow.Insert("FieldIsFilled"	, ValueIsFilled(Row[FieldName]));
				NewRow.Insert("Value"			, Row[FieldName]);
				NewRow.Insert("ValueSynonym"	, Row[FieldName + "Synonym"]);
				NewRow.Insert("TypeDescription"	, Field.Type);
				
				ObjectFields.Add(NewRow);
				
				FieldsAreFilled = FieldsAreFilled Or NewRow.FieldIsFilled;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return New Structure("FieldsAreFilled, ObjectFields", FieldsAreFilled, ObjectFields);
	
EndFunction

&AtClient
Function FieldsToFillInit()
	
	FieldsToFill = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "Period");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'"));
	FieldStructure.Insert("Type"		, New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime)));
	FieldStructure.Insert("CheckType"	, "Standart");
	FieldsToFill.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "Currency");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"));
	FieldStructure.Insert("Type"		, New TypeDescription("CatalogRef.Currencies"));
	FieldStructure.Insert("CheckType"	, "DebitCredit");
	FieldsToFill.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "AmountCur");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	FieldStructure.Insert("Type"		, New TypeDescription("Number", , , New NumberQualifiers(15, 2)));
	FieldStructure.Insert("CheckType"	, "Synonym");
	FieldsToFill.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "Quantity");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	FieldStructure.Insert("Type"		, New TypeDescription("Number", , , New NumberQualifiers(15, 3)));
	FieldStructure.Insert("CheckType"	, "Synonym");
	FieldsToFill.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "Amount");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Amount'; ru = 'Сумма';pl = 'Wartość';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"));
	FieldStructure.Insert("Type"		, New TypeDescription("Number", , , New NumberQualifiers(15, 2)));
	FieldStructure.Insert("CheckType"	, "Synonym");
	FieldsToFill.Add(FieldStructure);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DimensionValue");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Dimension value'; ru = 'Значение измерения';pl = 'Wartość wymiaru';es_ES = 'Valor de dimensión';es_CO = 'Valor de dimensión';tr = 'Boyut değeri';it = 'Valore dimensione';de = 'Messungswert'"));
	FieldStructure.Insert("Type"		, Undefined);
	FieldStructure.Insert("CheckType"	, "DebitCredit");
	FieldsToFill.Add(FieldStructure);
	
	Return FieldsToFill;
	
EndFunction

&AtServer
Procedure FillEntriesAtServer(TabName, FieldsArray, OnlyEmpty)
	
	ObjectFields = New ValueTable;
	ObjectFields.Columns.Add("DataSource");
	ObjectFields.Columns.Add("Row");
	ObjectFields.Columns.Add("Field");
	ObjectFields.Columns.Add("Synonym");
	ObjectFields.Columns.Add("CheckType");
	ObjectFields.Columns.Add("DrCr");
	ObjectFields.Columns.Add("TypeDescription");
	ObjectFields.Columns.Add("Value");
	ObjectFields.Columns.Add("ValueSynonym");
	
	UseQuantity = Common.ObjectAttributeValue(Object.ChartOfAccounts, "UseQuantity");
	
	If UseQuantity = Undefined Then
		UseQuantity = False;
	EndIf;
	
	QuantityFields = "QuantityDr, QuantityCr, Quantity";
	
	For Each Item In FieldsArray Do
		
		If OnlyEmpty
			And Item.FieldIsFilled Then
			Continue;
		EndIf;
		
		If Not UseQuantity
			And StrFind(QuantityFields, Item.Field) <> 0 Then
			Continue;
		EndIf;
		
		NewRow = ObjectFields.Add();
		FillPropertyValues(NewRow, Item);
		
	EndDo;
	
	ErrorMessages = New Array;
	
	DataSourcesTable = ObjectFields.Copy(,"DataSource");
	DataSourcesTable.GroupBy("DataSource");
	ObjectField = "Object." + TabName + "[%1].%2";
	For Each DataSourceRow In DataSourcesTable Do
		
		Filter = New Structure("DataSource", DataSourceRow.DataSource);
		Rows = ObjectFields.FindRows(Filter);
		
		ErrorMessagesRow = WorkWithArbitraryParameters.FillDefaultParametersInTable(DataSourceRow.DataSource, Object.DocumentType, Rows, True);
		
		For Each ErrorStructure In ErrorMessagesRow Do
			ErrorMessages.Add(ErrorStructure);
		EndDo;
		
	EndDo;
	
	For Each Row In ObjectFields Do
		
		If Object[TabName][Row.Row].ConnectionKey = 0 Then
			DriveClientServer.FillConnectionKey(Object[TabName], Object[TabName][Row.Row], "ConnectionKey");
		EndIf;
		
		Object[TabName][Row.Row][Row.Field] = Row.Value;
		Object[TabName][Row.Row][Row.Field + "Synonym"] = Row.ValueSynonym;
		
		WorkWithArbitraryParameters.UpdateObjectSynonymsTS(
			Object,
			Row.Field,
			Object[TabName][Row.Row].ConnectionKey,
			Row.ValueSynonym);
		
	EndDo;
	
	Num = 0;
	For Each Row In Object[TabName] Do
		
		If TabName = "Entries" And TypeOf(Row.Account) = Type("ChartOfAccountsRef.MasterChartOfAccounts") Then
			
			RowAccountAttributes = Common.ObjectAttributesValues(Row.Account,"UseQuantity, Currency");
			
			If Not RowAccountAttributes.UseQuantity Then
				RemoveDataFromField(Row, "Quantity", ErrorMessages, Num);
			EndIf;
			
			If Not RowAccountAttributes.Currency Then
				RemoveDataFromField(Row, "Currency", ErrorMessages, Num);
				RemoveDataFromField(Row, "AmountCur", ErrorMessages, Num);
			EndIf;
			
		ElsIf TabName = "EntriesSimple" Then
			
			If TypeOf(Row.AccountDr) = Type("ChartOfAccountsRef.MasterChartOfAccounts") Then
				
				RowAccountAttributes = Common.ObjectAttributesValues(Row.AccountDr,"UseQuantity, Currency");
				
				If Not RowAccountAttributes.UseQuantity Then
					RemoveDataFromField(Row, "QuantityDr", ErrorMessages, Num);
				EndIf;
				
				If Not RowAccountAttributes.Currency Then
					RemoveDataFromField(Row, "CurrencyDr", ErrorMessages, Num);
					RemoveDataFromField(Row, "AmountCurDr", ErrorMessages, Num);
				EndIf;
				
			EndIf;
			
			If TypeOf(Row.AccountCr) = Type("ChartOfAccountsRef.MasterChartOfAccounts") Then
				
				RowAccountAttributes = Common.ObjectAttributesValues(Row.AccountCr,"UseQuantity, Currency");
				
				If Not RowAccountAttributes.UseQuantity Then
					RemoveDataFromField(Row, "QuantityCr", ErrorMessages, Num);
				EndIf;
				
				If Not RowAccountAttributes.Currency Then
					RemoveDataFromField(Row, "CurrencyCr", ErrorMessages, Num);
					RemoveDataFromField(Row, "AmountCurCr", ErrorMessages, Num);
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Num = Num + 1;
		
	EndDo;
	
	For Each ErrorMessage In ErrorMessages Do
		
		CommonClientServer.MessageToUser(
			ErrorMessage.Text,
			,
			StringFunctionsClientServer.SubstituteParametersToString(
				ObjectField,
				ErrorMessage.Row,
				ErrorMessage.Field + "Synonym"));
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillEntriesEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		FillEntriesAtServer(AdditionalParameters.TabName, AdditionalParameters.FieldsArray, True);
	ElsIf Result = DialogReturnCode.No Then
		FillEntriesAtServer(AdditionalParameters.TabName, AdditionalParameters.FieldsArray, False);
	EndIf;

EndProcedure

&AtClient
Procedure FillEntriesProcess(TabName)
	
	If Not ValueIsFilled(Object.DocumentType) Then
		Return
	EndIf;
	
	ClearMessages();
	
	FieldsToFill = FieldsToFillInit();
	
	ResultStructure = CheckEntriesAtServer(FieldsToFill);
	
	If ResultStructure.FieldsAreFilled Then
		
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes	, NStr("en = 'Fill empty'; ru = 'Заполнить пустые';pl = 'Wypełnij puste';es_ES = 'Rellenar el vacío';es_CO = 'Rellenar el vacío';tr = 'Boşları doldur';it = 'Riempire vuoto';de = 'Leere füllen'"));
		ButtonsList.Add(DialogReturnCode.No		, NStr("en = 'Fill all'; ru = 'Заполнить все';pl = 'Wypełnij wszystkie';es_ES = 'Rellenar todo';es_CO = 'Rellenar todo';tr = 'Tümünü doldur';it = 'Riempire tutti';de = 'Alle füllen'"));
		ButtonsList.Add(DialogReturnCode.Cancel	, NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annulla';de = 'Abbrechen'"));
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("FieldsArray"	, ResultStructure.ObjectFields);
		AdditionalParameters.Insert("TabName"		, TabName);
		
		Notification = New NotifyDescription("FillEntriesEnd", ThisObject, AdditionalParameters);
		
		QueryBoxText = NStr("en = 'Some fields are not empty.
			|Select option ""Fill empty"" to fill data only in the empty fields.
			|Select option ""Fill all"" to fill data all fields.
			|Select ""Cancel"" to cancel operation.'; 
			|ru = 'Некоторые поля заполнены.
			|Нажмите ""Заполнить пустые"", чтобы заполнить данными только пустые поля.
			|Нажмите ""Заполнить все"", чтобы заполнить данными все поля.
			|Нажмите ""Отмена"", чтобы отменить операцию.';
			|pl = 'Niektóre pola nie są puste.
			|Wybierz opcję ""Wypełnij puste"" aby wypełnić danymi tylko puste pola.
			|Wybierz opcję ""Wypełnij wszystkie"" aby wypełnić danymi wszystkie pola.
			|Wybierz ""Anuluj"" aby anulować operację.';
			|es_ES = 'Algunos campos no están vacíos.
			|Seleccione la variante ""Rellenar vacío"" para rellenar los datos sólo en los campos vacíos.
			|Seleccione la variante ""Rellenar todo"" para rellenar los datos de todos los campos.
			|Seleccione ""Cancelar"" para anular la operación.';
			|es_CO = 'Algunos campos no están vacíos.
			|Seleccione la variante ""Rellenar vacío"" para rellenar los datos sólo en los campos vacíos.
			|Seleccione la variante ""Rellenar todo"" para rellenar los datos de todos los campos.
			|Seleccione ""Cancelar"" para anular la operación.';
			|tr = 'Bazı alanlar boş değil.
			|Sadece boş alanlara veri doldurmak için ""Boşları doldur"" seçeneğini seçin.
			|Tüm alanları doldurmak için ""Tümünü doldur""u seçin.
			|İşlemi iptal etmek için ""İptal""i seçin.';
			|it = 'Alcuni campi non sono vuoti.
			| Selezionare l''opzione ""Riempire vuoti"" per compilare i dati solo nei campi vuoti.
			|Selezionare l''opzione ""Riempire tutti"" per compilare i dati di tutti i campi.
			|Selezionare ""Annulla"" per annullare l''operazione.';
			|de = 'Mehrere Felder sind nicht leer.
			|Wählen Sie Option ""Leere füllen"" aus, um Daten nur zu den leeren Feldern hinzuzufügen.
			|Wählen Sie Option ""Alle füllen"", um Daten zu allen Feldern füllen.
			|Wählen Sie ""Abbrechen"" aus, um operation abzubrechen.'");
		
		ShowQueryBox(Notification, QueryBoxText, ButtonsList);
		
		Return;
		
	EndIf;
	
	FillEntriesAtServer(TabName, ResultStructure.ObjectFields, False);
	
EndProcedure

&AtServer
Procedure CompareAnalyticalDimensions(CurrentData, Account, DrCr, NameAdding)
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	If Account = Undefined Or Account = "" Or Not Account.UseAnalyticalDimensions Then
		
		For i = 1 To MaxAnalyticalDimensionsNumber Do
			CurrentData[StrTemplate("AnalyticalDimensions%1%2", NameAdding, i)] = Undefined;
			CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, i)] = Undefined;
			CurrentData[StrTemplate("AnalyticalDimensions%1%2Synonym", NameAdding, i)] = Undefined;
			
			WorkWithArbitraryParameters.DeleteRowsByConnectionKey(
				Object.ElementsSynonyms,
				"AnalyticalDimensions" + NameAdding + i,
				CurrentData.ConnectionKey);
		EndDo;
		
	Else
		
		AnalyticalDimensions = New ValueTable;
		AnalyticalDimensions.Columns.Add("AnalyticalDimension");
		AnalyticalDimensions.Columns.Add("AnalyticalDimensionsType");
		AnalyticalDimensions.Columns.Add("AnalyticalDimensionsSynonym");
		
		For i = 1 To MaxAnalyticalDimensionsNumber Do
			
			If Not ValueIsFilled(CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, i)]) Then
				Break;
			EndIf;
			
			NewRow = AnalyticalDimensions.Add();
			NewRow.AnalyticalDimension = CurrentData[StrTemplate("AnalyticalDimensions%1%2", NameAdding, i)];
			NewRow.AnalyticalDimensionsType = CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, i)];
			NewRow.AnalyticalDimensionsSynonym = CurrentData[StrTemplate("AnalyticalDimensions%1%2Synonym", NameAdding, i)];
		EndDo;
		
		Num = 1;
		For Each AnalyticalDimension In Account.ExtDimensionTypes Do
			
			FoundRow = AnalyticalDimensions.Find(AnalyticalDimension.ExtDimensionType, "AnalyticalDimensionsType");
			If FoundRow <> Undefined Then
				CurrentData[StrTemplate("AnalyticalDimensions%1%2", NameAdding, Num)] = FoundRow.AnalyticalDimension;
				CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, Num)] = FoundRow.AnalyticalDimensionsType;
				CurrentData[StrTemplate("AnalyticalDimensions%1%2Synonym", NameAdding, Num)] = FoundRow.AnalyticalDimensionsSynonym;
				
				WorkWithArbitraryParameters.UpdateObjectSynonymsTS(
					Object,
					"AnalyticalDimensions" + NameAdding + Num,
					CurrentData.ConnectionKey,
					FoundRow.AnalyticalDimensionsSynonym);
				
			Else
				CurrentData[StrTemplate("AnalyticalDimensions%1%2", NameAdding, Num)] = Undefined;
				CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, Num)] = AnalyticalDimension.ExtDimensionType;
				CurrentData[StrTemplate("AnalyticalDimensions%1%2Synonym", NameAdding, Num)] = Undefined;
				
				WorkWithArbitraryParameters.DeleteRowsByConnectionKey(
					Object.ElementsSynonyms, 
					"AnalyticalDimensions" + NameAdding + Num, 
					CurrentData.ConnectionKey);		
				
			EndIf;
			
			Num = Num + 1;
			
		EndDo;
		
		For i = Num To MaxAnalyticalDimensionsNumber Do
			CurrentData[StrTemplate("AnalyticalDimensions%1%2", NameAdding, i)] = Undefined;
			CurrentData[StrTemplate("AnalyticalDimensionsType%1%2", NameAdding, i)] = Undefined;
			CurrentData[StrTemplate("AnalyticalDimensions%1%2Synonym", NameAdding, i)] = Undefined;
			
			WorkWithArbitraryParameters.DeleteRowsByConnectionKey(
				Object.ElementsSynonyms, 
				"AnalyticalDimensions" + NameAdding + i, 
				CurrentData.ConnectionKey);		
			
		EndDo;
		
	EndIf;
	
	If Account = Undefined Or Account = "" Then
		CurrentData[StrTemplate("AnalyticalDimensionsSet%1", NameAdding)] = Undefined;
	Else
		CurrentData[StrTemplate("AnalyticalDimensionsSet%1", NameAdding)] = Account.AnalyticalDimensionsSet;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAccountReferenceFields(CurrentData, Account, DrCr, NameAdding)
	
	If AccountingApprovalServer.GetMasterByChartOfAccounts(Object.ChartOfAccounts) Then
		
		If Account = Undefined Then
			CurrentData[StrTemplate("DefaultAccountType%1", NameAdding)] = Undefined;
			CurrentData[StrTemplate("AccountReferenceName%1", NameAdding)] = Undefined;
		EndIf;
		
		If Account = Undefined Or Account = "" Or Not Account.UseQuantity Then
			CurrentData[StrTemplate("Quantity%1", NameAdding)] = Undefined;
			CurrentData[StrTemplate("Quantity%1%2Synonym", NameAdding)] = Undefined;
		
			WorkWithArbitraryParameters.DeleteRowsByConnectionKey(Object.ElementsSynonyms, "Quantity" + NameAdding, CurrentData.ConnectionKey);
		
		EndIf;
		
		If Account = Undefined Or Account = "" Or Not Account.Currency Then
			CurrentData[StrTemplate("AmountCur%1", NameAdding)] = Undefined;
			CurrentData[StrTemplate("AmountCur%1%2Synonym", NameAdding)] = Undefined;
			
			CurrentData[StrTemplate("Currency%1", NameAdding)] = Undefined;
			CurrentData[StrTemplate("Currency%1%2Synonym", NameAdding)] = Undefined;
		
			WorkWithArbitraryParameters.DeleteAllRowsByConnectionKey(Object.EntriesDefaultAccounts, CurrentData.ConnectionKey, "EntryConnectionKey");
			WorkWithArbitraryParameters.DeleteRowsByConnectionKey(Object.ElementsSynonyms, "Currency" + NameAdding, CurrentData.ConnectionKey);
			WorkWithArbitraryParameters.DeleteRowsByConnectionKey(Object.ElementsSynonyms, "AmountCur" + NameAdding, CurrentData.ConnectionKey);
		EndIf;
		
		CompareAnalyticalDimensions(CurrentData, Account, DrCr, NameAdding);
		
	EndIf;
	
EndProcedure

&AtServer
Function GetAvailableDataSourcesTable(DocumentType)
	
	AttributesTable = WorkWithArbitraryParameters.InitParametersTable();
	WorkWithArbitraryParameters.GetAvailableDataSourcesTable(AttributesTable, DocumentType);
	
	Return AttributesTable.UnloadColumn("Field");
	
EndFunction

&AtClient
Procedure ClearDataSources(DocumentType)

	If CurrentDocumentType <> DocumentType Then
		
		FieldsStructureEntriesDefaultAccounts = GetFieldStructureForChecking("EntriesDefaultAccounts");
		FieldsStructureEntriesFilters = GetFieldStructureForChecking("EntriesFilters");
		FieldsStructure = GetFieldStructureForChecking("Entries");
		DataSourceArray = GetAvailableDataSourcesTable(DocumentType);
		For Each Row In Object.Entries Do
			
			If Not ValueIsFilled(Row.DataSource)
				Or DataSourceArray.Find(Row.DataSource) <> Undefined Then
				Continue;
			EndIf;
			
			FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
				Row,
				Row.DataSource,
				"DataSource",
				FieldsStructure);
			
			WorkWithArbitraryParametersClient.ClearTabSectionRow(Row, FieldsToRemoveData);
			
			For Each Field In FieldsToRemoveData Do
				WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ElementsSynonyms, Field, Row.ConnectionKey);
			EndDo;
			
			Filter = New Structure;
			Filter.Insert("EntryConnectionKey", Row.ConnectionKey);
			FoundRows = Object.EntriesFilters.FindRows(Filter);
			For Each FilterRow In FoundRows Do
				
				FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
					FilterRow,
					Row.DataSource,
					"DataSource",
					FieldsStructureEntriesFilters);
				For Each Attribute In FieldsToRemoveData Do
					Object.EntriesFilters.Delete(FilterRow);
				EndDo;
				
			EndDo;
			
			FoundRows = Object.EntriesFilters.FindRows(Filter);
			StringFilterPresentation = "";
			
			For Each FilterRow In FoundRows Do
				StringFilterPresentation = StringFilterPresentation 
					+ StrTemplate("%1 %2 %3;",
						FilterRow.ParameterSynonym,
						FilterRow.ConditionPresentation,
						FilterRow.ValuePresentation);
			EndDo;
			
			Row.FilterPresentation = StringFilterPresentation;
			
			Row.DataSource			= Undefined;
			Row.DataSourceSynonym	= Undefined;
			
		EndDo;
		
		FieldsStructure = GetFieldStructureForChecking("EntriesSimple");
		For Each Row In Object.EntriesSimple Do
			
			If Not ValueIsFilled(Row.DataSource)
				Or DataSourceArray.Find(Row.DataSource) <> Undefined Then
				Continue;
			EndIf;
			
			FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
				Row,
				Row.DataSource,
				"DataSource",
				FieldsStructure);
			
			WorkWithArbitraryParametersClient.ClearTabSectionRow(Row, FieldsToRemoveData);
			
			For Each Field In FieldsToRemoveData Do
				WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ElementsSynonyms, Field, Row.ConnectionKey);
			EndDo;
			
			Filter = New Structure;
			Filter.Insert("EntryConnectionKey", Row.ConnectionKey);
			FoundRows = Object.EntriesFilters.FindRows(Filter);
			For Each FilterRow In FoundRows Do
				
				FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(
					FilterRow,
					Row.DataSource,
					"DataSource",
					FieldsStructureEntriesFilters);
				
				For Each Attribute In FieldsToRemoveData Do
					Object.EntriesFilters.Delete(FilterRow);
				EndDo;
				
			EndDo;
			
			FoundRows = Object.EntriesFilters.FindRows(Filter);
			StringFilterPresentation = "";
			
			For Each FilterRow In FoundRows Do
				StringFilterPresentation = StringFilterPresentation 
					+ StrTemplate("%1 %2 %3;",
						FilterRow.ParameterSynonym,
						FilterRow.ConditionPresentation,
						FilterRow.ValuePresentation);
			EndDo;
			
			Filter = New Structure;
			Filter.Insert("EntryConnectionKey", Row.ConnectionKey);
			FoundRows = Object.EntriesDefaultAccounts.FindRows(Filter);
			For Each FilterRow In FoundRows Do
				
				FieldsToRemoveData = WorkWithArbitraryParametersClient.CheckTemplateFieldsData(FilterRow, Row.DataSource, "DataSource", FieldsStructureEntriesDefaultAccounts);
				For Each Attribute In FieldsToRemoveData Do
					FilterRow[Attribute] = "";
					FilterRow[Attribute + "Synonym"] = "";
				EndDo;
				
			EndDo;
			
			Row.FilterPresentation = StringFilterPresentation ;
			
			Row.DataSource			= Undefined;
			Row.DataSourceSynonym	= Undefined;
			
		EndDo;
		
	EndIf;

EndProcedure

&AtClient
Procedure AmountCurStartChoice(StandardProcessing, TabName, NameAdding)
	
	StandardProcessing = False;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "DocumentTypeSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	FieldStructure.Insert("ObjectName"	, "Object");
	
	FieldsArray.Add(FieldStructure);
	
	CheckObjectResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(Object, FieldsArray);
	
	CurrentData = Items[TabName].CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, StrTemplate("Account%1Synonym", NameAdding));
	FieldStructure.Insert("Synonym"		, StrTemplate(NStr("en = 'Account'; ru = 'Счет';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'")));
	FieldStructure.Insert("ObjectName"	, StrTemplate("Object.%1", TabName));
	FieldStructure.Insert("RowCount"	, CurrentData.LineNumber - 1);
	
	FieldsArray.Add(FieldStructure);
	
	CheckRowResult = WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray, False);
	
	If Not CheckObjectResult
		Or Not CheckRowResult Then
		Return;
	EndIf;
	
	If CurrentData[StrTemplate("Account%1", NameAdding)] <> Undefined
		And Not GetAccountFlag(CurrentData[StrTemplate("Account%1", NameAdding)], "Currency") Then
		Return;
	EndIf;
	
	IDAdding = "";
	If TabName = "Entries" And CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Dr") Then
		IDAdding = "Dr";
	ElsIf TabName = "Entries" And CurrentData.DrCr = PredefinedValue("Enum.DebitCredit.Cr") Then
		IDAdding = "Cr";
	ElsIf TabName = "EntriesSimple" Then
		IDAdding = NameAdding;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"	, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"	, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentValue"	, CurrentData[StrTemplate("AmountCur%1", NameAdding)]);
	ChoiceFormParameters.Insert("FillAmounts"	, True);
	ChoiceFormParameters.Insert("FormulaMode"	, True);
	ChoiceFormParameters.Insert("AttributeName"	, NStr("en = 'amount (transaction currency)'; ru = 'сумма (валюта операции)';pl = 'wartość (waluta transakcji)';es_ES = 'importe (moneda de transacción)';es_CO = 'importe (moneda de transacción)';tr = 'tutar (işlem para birimi)';it = 'importo (valuta transazione)';de = 'Betrag (Transaktionswährung)'"));
	ChoiceFormParameters.Insert("NameAdding"	, NameAdding);
	ChoiceFormParameters.Insert("IDAdding"		, IDAdding);
	ChoiceFormParameters.Insert("AttributeID"	, "AmountCur");
	ChoiceFormParameters.Insert("DrCr"			, GetDrCr(StrTemplate("AmountCur%1", NameAdding), CurrentData.ConnectionKey));
	
	AttributeSynonym = WorkWithArbitraryParametersClient.GetAttributeSynonym(Object.ElementsSynonyms,
		StrTemplate("AmountCur%1", NameAdding), CurrentData.ConnectionKey);
	WorkWithArbitraryParametersClient.FillFormulaParameters(CurrentData, StrTemplate("AmountCur%1", NameAdding),
		AttributeSynonym, ChoiceFormParameters);
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", StrTemplate("AmountCur%1", NameAdding));
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SetChoiceParameters()
	
	ChoiceParametersArray = New Array;
	
	Items.ParametersValue.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	
	CurrentData = Items.Parameters.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ParameterNameArray = StrSplit(CurrentData.ParameterName, ".");
	
	If ParameterNameArray.Count() < 3 Then
		Return;
	EndIf;
	
	If ParameterNameArray[1] <> "AdditionalAttribute" Then
		Return;
	EndIf;
	
	TypeObjectsPropertiesValues = Type("CatalogRef.ObjectsPropertiesValues");

	If Not CurrentData.ValueType.ContainsType(TypeObjectsPropertiesValues) Then
		Return;
	EndIf;
	
	Owner = WorkWithArbitraryParametersClient.GetAdditionalParameterType(ParameterNameArray[2]);
	
	AdditionalPropertyValues = GetAdditionalPropertyValues(Owner);
	
	ChoiceParameter = New ChoiceParameter("Filter.Ref", New FixedArray(AdditionalPropertyValues));

	ChoiceParametersArray.Add(ChoiceParameter);
	
	Items.ParametersValue.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	
EndProcedure

&AtServerNoContext
Function GetAdditionalPropertyValues(Owner) 
	
	AdditionalPropertyValues = PropertyManagerInternal.AdditionalPropertyValues(Owner);
	
	Return AdditionalPropertyValues; 
EndFunction

&AtServer
Procedure FillCurrentObjectAttributes()
	
	CurrentTypeOfAccounting	= Object.TypeOfAccounting;
	CurrentDocumentType		= Object.DocumentType;
	CurrentChartOfAccounts	= Object.ChartOfAccounts;
	CurrentPlanStartDate	= Object.PlanStartDate;
	CurrentPlanEndDate		= Object.PlanEndDate;
	CurrentStartDate		= Object.StartDate;
	CurrentEndDate			= Object.EndDate;
	CurrentStatus			= Object.Status;
	CurrentCompany			= Object.Company;
	
EndProcedure

&AtServer
Procedure PositionToGivenElement()
		
	If Not Parameters.Property("TabName") Then
		Return;
	EndIf;
	
	ThisObject.CurrentItem = Items[Parameters.TabName];
	
	If Parameters.TabName = "EntriesSimple" And Parameters.Property("EntryLineNumber") Then
		
		Filter = New Structure;
		Filter.Insert("LineNumber", Parameters.EntryLineNumber);
		
		Rows = Object.EntriesSimple.FindRows(Filter);
		
		If Rows.Count() > 0 Then
			
			Items[Parameters.TabName].CurrentRow = Rows[0].GetID();
			
			If Items.Find(Parameters.FieldName) <> Undefined Then
				Items[Parameters.TabName].CurrentItem = Items[Parameters.FieldName];
			EndIf;
			
		EndIf;
		
	ElsIf Parameters.TabName = "Entries" And Parameters.Property("EntryNumber") Then
		
		Filter = New Structure;
		Filter.Insert("EntryNumber"		, Parameters.EntryNumber);
		Filter.Insert("EntryLineNumber"	, Parameters.EntryLineNumber);
		
		Rows = Object.Entries.FindRows(Filter);
		
		If Rows.Count() > 0 Then
			Items[Parameters.TabName].CurrentRow = Rows[0].GetID();
			
			If Items.Find(Parameters.FieldName) <> Undefined Then
				Items[Parameters.TabName].CurrentItem = Items[Parameters.FieldName];
			EndIf;
			
		EndIf;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure FillItemsForAccountSelection(Field, ItemName, LineNumber, FieldName)
	
	If Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr1"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr1"
		Or Field.Name = "EntriesAnalyticalDimensionsType1" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 1;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionType";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr2"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr2"
		Or Field.Name = "EntriesAnalyticalDimensionsType2" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 2;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionType";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr3"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr3"
		Or Field.Name = "EntriesAnalyticalDimensionsType3" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 3;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionType";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsTypeDr4"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsTypeCr4"
		Or Field.Name = "EntriesAnalyticalDimensionsType4" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 4;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionType";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsDr1Synonym"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr1Synonym"
		Or Field.Name = "EntriesAnalyticalDimensions1Synonym" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 1;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionValueSynonym";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsDr2Synonym"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr2Synonym"
		Or Field.Name = "EntriesAnalyticalDimensions2Synonym" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 2;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionValueSynonym";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsDr3Synonym"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr3Synonym"
		Or Field.Name = "EntriesAnalyticalDimensions3Synonym" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 3;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionValueSynonym";
		
	ElsIf Field.Name = "EntriesSimpleAnalyticalDimensionsDr4Synonym"
		Or Field.Name = "EntriesSimpleAnalyticalDimensionsCr4Synonym"
		Or Field.Name = "EntriesAnalyticalDimensions4Synonym" Then
		
		ItemName = "AnalyticalDimensions";
		LineNumber = 4;
		FieldName = "AnalyticalDimensionsAnalyticalDimensionValueSynonym";
		
	ElsIf Field.Name = "EntriesSimpleDimensionSetDr"
		Or Field.Name = "EntriesSimpleDimensionSetCr"
		Or Field.Name = "EntriesDimensionSet" Then
		
		ItemName = "AnalyticalDimensionsSet";
		LineNumber = 0;
		FieldName = "";
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RemoveDataFromField(Row, Field, ErrorMessages, Num)

	Row[Field]							 = Undefined;
	Row[StrTemplate("%1Synonym", Field)] = Undefined;
	
	WorkWithArbitraryParameters.DeleteRowsByConnectionKey(Object.ElementsSynonyms, Field, Row.ConnectionKey);
	
	ErrorsCount = ErrorMessages.Count();
	While ErrorsCount > 0 Do
		
		ErrorsCount = ErrorsCount - 1;
		Item = ErrorMessages[ErrorsCount];
		
		If Item.Row = Num And Item.Field = Field Then
			ErrorMessages.Delete(ErrorsCount);
		EndIf;
		
	EndDo;
	
EndProcedure // RemoveDataFromField()

&AtServer
Procedure ClearFilters(RowKey)
	
	FilterCurrentString	= New Structure("EntryConnectionKey", RowKey);
	DeleteRowsArray		= New FixedArray(Object.EntriesFilters.FindRows(FilterCurrentString));
	
	For Each RowDelete In DeleteRowsArray Do
		Object.EntriesFilters.Delete(RowDelete);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetEnabledByRight()
	
	HasRights = AccessRight("Edit", Metadata.Catalogs.AccountingEntriesTemplates);
	
	If Not HasRights Then
		SetItemsEnabled(Items.Entries.CommandBar.ChildItems, False);
		SetItemsEnabled(Items.Entries.ContextMenu.ChildItems, False);
		SetItemsEnabled(Items.EntriesSimple.CommandBar.ChildItems, False);
		SetItemsEnabled(Items.EntriesSimple.ContextMenu.ChildItems, False);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetItemsEnabled(Group, Enabled)
	For Each Item In Group Do
		If TypeOf(Item) = Type("CommandGroup")
			Or TypeOf(Item) = Type("FormGroup") Then
			SetItemsEnabled(Item.ChildItems, Enabled)
		Else
			Item.Enabled = Enabled;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure TestTemplate(Command)
	
	If Modified Or Not ValueIsFilled(Object.Ref) Then
		
		MessageText = NStr("en = 'The template will be saved. Continue?'; ru = 'Шаблон будет сохранен. Продолжить?';pl = 'Szablon zostanie zapisany. Kontynuować?';es_ES = 'La plantilla será guardada. ¿Continuar?';es_CO = 'La plantilla será guardada. ¿Continuar?';tr = 'Şablon kaydedilecek. Devam edilsin mi?';it = 'Il modello verrà salvato. Continuare?';de = 'Die Vorlage wird gespeichert. Weiter?'");
		Notification = New NotifyDescription("TestTemplateEnd", ThisObject);
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Return;
		
	EndIf;
	
	OpenTestTemplateForm();
	
EndProcedure

&AtClient
Procedure TestTemplateEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		WriteParameters = New Structure;
		WriteParameters.Insert("OpenTestTemplateForm", True);
		Write(WriteParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenTestTemplateForm()
	
	FormParameters = New Structure("Template", Object.Ref);
	OpenForm("DataProcessor.AccountingTemplatesTesting.Form.AccountingTemplateTesting",
		FormParameters,
		ThisObject,
		Object.Ref,
		,
		,
		,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion