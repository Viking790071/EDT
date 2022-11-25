
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FormTitle = Title;
	
	If Parameters.NewRecord Then
		
		IsNew	= True;
		Period	= ?(Parameters.Property("Period")	, Parameters.Period	, CurrentSessionDate());
		Company	= ?(Parameters.Property("Company")	, Parameters.Company, Catalogs.Companies.CompanyByDefault());
		Author	= ?(Parameters.Property("Author")	, Parameters.Company, Users.CurrentUser());

		Parameters.Property("TypeOfAccounting", TypeOfAccounting);
		Parameters.Property("IsCopy", IsCopy);
		
		If ValueIsFilled(Company) And Not ValueIsFilled(TypeOfAccounting) Then
			
			Query = New Query;
			Query.Text = 
			"SELECT ALLOWED DISTINCT
			|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting
			|FROM
			|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(, Company = &Company) AS CompaniesTypesOfAccounting";
			
			Query.SetParameter("Company", Company);
			
			Result = Query.Execute().Unload();
			
			If Result.Count() = 1 Then
				TypeOfAccounting = Result[0].TypeOfAccounting;
			EndIf;
			
		EndIf;
		
		Title = StrTemplate(NStr("en = '%1 (create)'; ru = '%1 (создание)';pl = '%1 (tworzenie)';es_ES = '%1 (creación)';es_CO = '%1 (creación)';tr = '%1 (oluştur)';it = '%1 (crea)';de = '%1 (Erstellen)'"), Title);
		
	Else
		
		Period				= Parameters.Period;
		Company				= Parameters.Company;
		TypeOfAccounting	= Parameters.TypeOfAccounting;
		Author				= Parameters.Author;
		
		CompanyOnOpen			= Company;
		PeriodOnOpen			= Period;
		TypeOfAccountingOnOpen	= TypeOfAccounting;
		
	EndIf;
	
	CompanyOld				= Company;
	PeriodOld				= Period;
	TypeOfAccountingOld		= TypeOfAccounting;
	
	FillDocumentTypeListAtServer(IsCopy);
	
	RefreshAvailableTypesOfAccountingList();
	
	HasUpdateRole = AccessRight("Update", Metadata.InformationRegisters.AccountingSourceDocuments);
	Items.FormSaveAndClose.Enabled	= HasUpdateRole;
	Items.FormSave.Enabled			= HasUpdateRole;
	ReadOnly						= Not HasUpdateRole;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("AfterOpenForm", 0.1, True);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Modified Then
		
		Cancel = True;
		
		ShowQueryBox(New NotifyDescription("AfterClosingQuestion", ThisObject),
			NStr("en = 'Data has been changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';es_CO = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Wollen Sie die Änderungen speichern?'"),
			QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	If Company <> CompanyOld Then
		CheckAccountingPolicy("Company");
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	If ValueIsFilled(Company) And Period <> PeriodOld Then
		
		CheckAccountingPolicy("Period");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TypeOfAccountingOnChange(Item)
	
	If TypeOfAccounting = TypeOfAccountingOld Then
		Return;
	EndIf;
	
	TypeOfAccountingActive = IsChosenTypeOfAccountingActive(TypeOfAccounting);
	
	If TypeOfAccountingActive Then
		
		TypeOfAccountingRefreshEnd(DialogReturnCode.Yes, Undefined);
		
	Else
		
		Notification = New NotifyDescription("TypeOfAccountingOnChangeEnd", ThisObject);
		Mode = QuestionDialogMode.YesNo;
		QueryMessageTemplate = NStr("en = 'For the selected company ""%1"", the accounting policy states that %3 is not applicable on %2. 
			|The ""Type of accounting"" field and checkboxes in the document list will be cleared. 
			|Continue?'; 
			|ru = 'Для выбранной организации ""%1"" в учетной политике указано, что %3 не применяется на %2. 
			|Поле ""Тип бухгалтерского учета"" и флажки в списке документов будут очищены. 
			| Продолжить?';
			|pl = 'Dla wybranej firmy ""%1"", polityka rachunkowości stanowi, że %3 nie ma zastosowania na %2. 
			|Pole ""Typ rachunkowości"" i pole wyboru na liście dokumentów zostaną wyczyszczone. 
			|Kontynuować?';
			|es_ES = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %3 no es aplicable en %2.
			|El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán.
			|¿Continuar?';
			|es_CO = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %3 no es aplicable en %2.
			|El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán.
			|¿Continuar?';
			|tr = 'Seçilen ""%1"" iş yeri için, muhasebe politikasına göre %3, %2''de uygulanamaz. 
			|Belge listesindeki ""Muhasebe türü"" alanı ve onay kutuları temizlenecek. 
			|Devam edilsin mi?';
			|it = 'Per l''azienda ""%1"" selezionata, la politica contabile indica che %3 non è applicabile a %2. 
			| il campo ""Tipo di contabilità"" e le caselle di controllo nell''elenco del documento saranno eliminati. 
			|Continuare?';
			|de = 'Für die ausgewählte Firma ""%1"", bestimmen die Bilanzierungsrichtlinien dass %3 für %2 nicht verwendbar ist. 
			|Das Feld ""Typ der Buchhaltung"" und die Kontrollkästchen in der Dokumentenliste werden gelöscht. 
			|Weiter?'");
		
		ShowQueryBox(Notification, StrTemplate(QueryMessageTemplate, Company, Format(Period, "DLF=D"), TypeOfAccounting), Mode, 0);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TypeOfAccountingStartChoice(Item, ChoiceData, StandardProcessing)

	If Not ValueIsFilled(Period) Then
		
		MessageText = NStr("en = 'Fill ""Date"" and repeat.'; ru = 'Заполните поле ""Дата"" и повторите попытку.';pl = 'Wypełnij pole ""Data"" i powtórz.';es_ES = 'Rellenar ""Fecha"" y repetir.';es_CO = 'Rellenar ""Fecha"" y repetir.';tr = '""Tarih""i doldurup tekrarlayın.';it = 'Compilare ""Data"" e ripetere.';de = 'Füllen Sie ""Datum"" aus und machen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText, , "Period");
		
		StandardProcessing = False;
		
	EndIf;

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDocumentTypeList

&AtClient
Procedure DocumentTypeListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure DocumentTypeListOnChange(Item)
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	
	CheckRestrictions(False);
	
EndProcedure

&AtClient
Procedure SaveAndClose(Command)
	
	CheckRestrictions(True);
	
EndProcedure

&AtClient
Procedure RefreshDocumentTypeList(Command)
	
	If Not ValueIsFilled(Period) Then
		MessageText = NStr("en = 'Fill ""Date"" and repeat.'; ru = 'Заполните поле ""Дата"" и повторите попытку.';pl = 'Wypełnij pole ""Data"" i powtórz.';es_ES = 'Rellenar ""Fecha"" y repetir.';es_CO = 'Rellenar ""Fecha"" y repetir.';tr = '""Tarih""i doldurup tekrarlayın.';it = 'Compilare ""Data"" e ripetere.';de = 'Füllen Sie ""Datum"" aus und machen Sie erneut.'");
		CommonClientServer.MessageToUser(MessageText, , "Period");
		Return;
	EndIf;
	
	RefreshDocumentTypeListAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillDocumentTypeListAtServer(IsCopy = False)

	DocumentTypeList.Clear();
	DocumentTypeListOld.Clear();
	
	If ValueIsFilled(Company) And ValueIsFilled(TypeOfAccounting) And ValueIsFilled(Period) Then
		
		CurrChartOfAccounts = InformationRegisters.CompaniesTypesOfAccounting.GetChartOfAccounts(Company, TypeOfAccounting, Period);
		
		If Not ValueIsFilled(CurrChartOfAccounts) Then
			
			ErrMessage = NStr("en = 'For the selected company ""%1"", the accounting policy states that %2 is not applicable on %3. The document list is cleared.'; ru = 'Для выбранной организации ""%1"" в учетной политике указано, что %3 не применяется на %2. Список документов очищен.';pl = ' Dla wybranej firmy ""%1"", polityka rachunkowości stanowi, że %2 nie ma zastosowania na %3. Lista dokumentów jest wyczyszczona.';es_ES = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %2 no es aplicable en%3. La lista de documentos se borrará.';es_CO = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %2 no es aplicable en%3. La lista de documentos se borrará.';tr = 'Seçilen ""%1"" iş yeri için, muhasebe politikasına göre %2, %3''de uygulanamaz. Belge listesi temizlendi.';it = 'Per l''azienda ""%1"" selezionata, la politica contabile indica che %2 non è applicabile a %3. L''elenco del documento è eliminato.';de = 'Für die ausgewählte Firma ""%1"", bestimmen die Bilanzierungsrichtlinien dass %2 für %3 nicht verwendbar ist. Die Dokumentenliste ist gelöscht.'");
			DriveServer.ShowMessageAboutError(ThisObject, StrTemplate(ErrMessage, Company, TypeOfAccounting, Format(Period, "DLF=D")));
			
			Return;
			
		EndIf;
		
		AttributesTable = WorkWithArbitraryParameters.InitParametersTable();
		
		WorkWithArbitraryParameters.GetRecordersListByCoA(AttributesTable, CurrChartOfAccounts);

		AttributesTable.Sort("Synonym");
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	AccountingSourceDocuments.DocumentType AS DocumentType,
		|	AccountingSourceDocuments.Uses AS Uses
		|FROM
		|	InformationRegister.AccountingSourceDocuments AS AccountingSourceDocuments
		|WHERE
		|	AccountingSourceDocuments.Period = &Period
		|	AND AccountingSourceDocuments.Company = &Company
		|	AND AccountingSourceDocuments.TypeOfAccounting = &TypeOfAccounting";
		
		Query.SetParameter("Company", Company);
		Query.SetParameter("Period", Period);
		Query.SetParameter("TypeOfAccounting", TypeOfAccounting);
		
		QueryResult = Query.Execute();
		
		HaveASavedList = Not QueryResult.IsEmpty();
		
		Result = Query.Execute().Unload();
		
		For Each Row In AttributesTable Do
			
			If Row.Field.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
				Continue;
			EndIf;
			
			FoundedItem = Result.Find(Row.Field, "DocumentType");
			
			If FoundedItem = Undefined Then
				If IsCopy Then
					DocumentListIrrelevant = True;
				EndIf;
				
				If HaveASavedList Then
					Continue;
				Else
					DocumentTypeList.Add(Row.Field, Row.Synonym, True);
				EndIf;
			Else
				DocumentTypeList.Add(Row.Field, Row.Synonym, FoundedItem.Uses);
			EndIf;
			
		EndDo;
		
		DocumentTypeListOld = DocumentTypeList.Copy();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshDocumentTypeListAtServer()
	
	CurrentDocumentTypeList = DocumentTypeList.Copy();
	
	SavedListIsEmpty = (CurrentDocumentTypeList.Count() = 0);
	
	DocumentTypeList.Clear();
	DocumentTypeListOld.Clear();
	
	If ValueIsFilled(Company) And ValueIsFilled(TypeOfAccounting) And ValueIsFilled(Period) Then
		
		CurrChartOfAccounts = InformationRegisters.CompaniesTypesOfAccounting.GetChartOfAccounts(Company, TypeOfAccounting, Period);
		
		If Not ValueIsFilled(CurrChartOfAccounts) Then
			ErrMessage = NStr("en = 'For the selected company ""%1"", the accounting policy states that %2 is not applicable on %3. The document list is cleared.'; ru = 'Для выбранной организации ""%1"" в учетной политике указано, что %3 не применяется на %2. Список документов очищен.';pl = ' Dla wybranej firmy ""%1"", polityka rachunkowości stanowi, że %2 nie ma zastosowania na %3. Lista dokumentów jest wyczyszczona.';es_ES = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %2 no es aplicable en%3. La lista de documentos se borrará.';es_CO = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %2 no es aplicable en%3. La lista de documentos se borrará.';tr = 'Seçilen ""%1"" iş yeri için, muhasebe politikasına göre %2, %3''de uygulanamaz. Belge listesi temizlendi.';it = 'Per l''azienda ""%1"" selezionata, la politica contabile indica che %2 non è applicabile a %3. L''elenco del documento è eliminato.';de = 'Für die ausgewählte Firma ""%1"", bestimmen die Bilanzierungsrichtlinien dass %2 für %3 nicht verwendbar ist. Die Dokumentenliste ist gelöscht.'");
			DriveServer.ShowMessageAboutError(ThisObject, StrTemplate(ErrMessage, Company, TypeOfAccounting, Format(Period, "DLF=D")));
			Return;
		EndIf;
		
		AttributesTable = WorkWithArbitraryParameters.InitParametersTable();
		
		WorkWithArbitraryParameters.GetRecordersListByCoA(AttributesTable, CurrChartOfAccounts);

		AttributesTable.Sort("Synonym");
		
		For Each Row In AttributesTable Do
			
			If Row.Field.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
				Continue;
			EndIf;
			
			FoundedItem = CurrentDocumentTypeList.FindByValue(Row.Field);
			
			If FoundedItem = Undefined Then
				DocumentTypeList.Add(Row.Field, Row.Synonym, SavedListIsEmpty);
			Else
				DocumentTypeList.Add(Row.Field, Row.Synonym, FoundedItem.Check);
			EndIf;
			
		EndDo;
		
		DocumentTypeListOld = DocumentTypeList.Copy();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveAtServer()
	
	If ValueIsFilled(PeriodOnOpen) 
		And (PeriodOnOpen <> Period Or CompanyOnOpen <> Company Or TypeOfAccountingOnOpen <> TypeOfAccounting) Then
		
		RegSet = InformationRegisters.AccountingSourceDocuments.CreateRecordSet();
		
		RegSet.Filter.Company.Use				= True;
		RegSet.Filter.Company.Value				= CompanyOnOpen;
		RegSet.Filter.TypeOfAccounting.Use		= True;
		RegSet.Filter.TypeOfAccounting.Value	= TypeOfAccountingOnOpen;
		RegSet.Filter.Period.Use				= True;
		RegSet.Filter.Period.Value				= PeriodOnOpen;
		
		RegSet.Write();
		
	EndIf;
	
	For Each DocumentTypeEl In DocumentTypeList Do
		
		RegManager = InformationRegisters.AccountingSourceDocuments.CreateRecordManager();
		
		RegManager.Period			= Period;
		RegManager.Company			= Company;
		RegManager.TypeOfAccounting	= TypeOfAccounting;
		RegManager.DocumentType		= DocumentTypeEl.Value;
		RegManager.Uses				= DocumentTypeEl.Check;
		RegManager.Author			= Author;
		
		RegManager.Write();
		
	EndDo;
	
	PeriodOnOpen			= Period;
	CompanyOnOpen			= Company;
	TypeOfAccountingOnOpen	= TypeOfAccounting;
	
	Title	 = FormTitle;
	Modified = False;
	IsNew	 = False;
	
EndProcedure

&AtServer
Function CheckRestrictionsAtServer()
	
	Result	 = True;
	Messages = New Array;
	
	If Not ValueIsFilled(Company) Then
		Result = False;
		Message = New Structure;
		Message.Insert("Text"	, NStr("en = '""Company"" is required field. Fill it and try again.'; ru = 'Укажите организацию и повторите попытку.';pl = 'Pole ""Firma"" jest wymagane. Wypełnij go i spróbuj ponownie.';es_ES = '""Empresa"" es un campo obligatorio. Rellénelo e inténtelo de nuevo.';es_CO = '""Empresa"" es un campo obligatorio. Rellénelo e inténtelo de nuevo.';tr = 'Zorunlu ""İş yeri"" alanını doldurup tekrar deneyin.';it = '""Azienda"" è un campo richiesto. Compilare e riprovare.';de = '""Firma"" ist ein Pflichtfeld. Füllen Sie es aus und versuchen erneut.'"));
		Message.Insert("Field"	, "Company");
		Messages.Add(Message);
	EndIf;
	
	If Not ValueIsFilled(TypeOfAccounting) Then
		Result = False;
		Message = New Structure;
		Message.Insert("Text"	, NStr("en = '""Type of accounting"" is required field. Fill it and try again.'; ru = 'Заполните поле ""Тип бухгалтерского учета"" и повторите попытку.';pl = 'Pole ""Typ rachunkowości"" jest wymagane. Wypełnij go i spróbuj ponownie.';es_ES = '""Tipo de contabilidad"" es un campo obligatorio. Rellénelo y vuelva a intentarlo.';es_CO = '""Tipo de contabilidad"" es un campo obligatorio. Rellénelo y vuelva a intentarlo.';tr = 'Zorunlu ""Muhasebe türü"" alanını doldurup tekrar deneyin.';it = '""Tipo di contabilità"" è un campo richiesto. Compilarlo e riprovare.';de = '""Typ der Buchhaltung"" ist ein Pflichtfeld. Füllen Sie es aus und versuchen erneut.'"));
		Message.Insert("Field"	, "TypeOfAccounting");
		Messages.Add(Message);
	EndIf;
	
	If IsNew Then
		
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	AccountingSourceDocuments.DocumentType AS DocumentType
		|FROM
		|	InformationRegister.AccountingSourceDocuments AS AccountingSourceDocuments
		|WHERE
		|	AccountingSourceDocuments.Period = &Period
		|	AND AccountingSourceDocuments.Company = &Company
		|	AND AccountingSourceDocuments.TypeOfAccounting = &TypeOfAccounting";
		
		Query.SetParameter("Company"			, Company);
		Query.SetParameter("Period"				, Period);
		Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		Template = NStr("en = 'Cannot save the changes. For %1 and %2, the list of Accounting source documents already exists on %3.'; ru = 'Не удалось сохранить изменения. Для %1 и %2 на %3 уже существует список первичных документов бухгалтерского учета.';pl = 'Nie można zapisać zmian. Dla %1 i %2, lista Źródłowych dokumentów księgowych już istnieje na %3.';es_ES = 'No se pueden guardar los cambios. Para%1y %2, la lista de documentos de fuente de contabilidad ya existe en%3.';es_CO = 'No se pueden guardar los cambios. Para%1y %2, la lista de documentos de fuente de contabilidad ya existe en%3.';tr = 'Değişiklikler kaydedilemiyor. %1 ve %2 için, %3''de zaten Muhasebe kaynak belgeleri listesi mevcut.';it = 'Impossibile salvare le modifiche. Per %1 e %2, l''elenco dei documenti fonte di contabilità esiste già in %3.';de = 'Fehler beim Speichern von Änderungen. Für %1 und %2, besteht die Liste von Buchhaltungsquelldokumenten bereits in %3.'");
		While SelectionDetailRecords.Next() Do
			
			Result = False;
			
			Message = New Structure;
			Message.Insert("Text"	, StrTemplate(Template, Company, TypeOfAccounting, Format(Period, "DLF=D")));
			Message.Insert("Field"	, "Period");
			Messages.Add(Message);
			
		EndDo;
		
	EndIf;
	
	If Result Then
		Question = Undefined;
		ChosenDocumentTypes	 = New Array;
		EditedDocumentTypes	 = New Array;
		
		For Each DocumentTypeItem In DocumentTypeList Do
			
			If DocumentTypeItem.Check Then
				ChosenDocumentTypes.Add(DocumentTypeItem.Value);
			EndIf;
			
			OldValue = DocumentTypeListOld.FindByValue(DocumentTypeItem.Value);
			If OldValue = Undefined And DocumentTypeItem.Check 
				Or OldValue <> Undefined And OldValue.Check <> DocumentTypeItem.Check Then
				EditedDocumentTypes.Add(DocumentTypeItem.Value);
			EndIf;
			
		EndDo;
		
		CheckDocumentsAfterSetDate(Result, Messages, EditedDocumentTypes);
		
		If Result And ChosenDocumentTypes.Count() = 0 Then
			
			Result	 = False;
			Question = New Structure;
			Question.Insert("Message", NStr("en = 'You have not selected any documents. Continue?'; ru = 'Не выбрано никаких документов. Продолжить?';pl = 'Nie wybrano żadnych dokumentów. Kontynuować?';es_ES = 'No ha seleccionado ningún documento. ¿Continuar?';es_CO = 'No ha seleccionado ningún documento. ¿Continuar?';tr = 'Belge seçmediniz. Devam edilsin mi?';it = 'Non è stato selezionato alcun documento. Continuare?';de = 'Sie haben keine Dokumente ausgewählt. Weiter?'"));
			Question.Insert("Buttons", "YesNo");
			Question.Insert("ContinueResult", "Yes");
			
		EndIf;
	EndIf;
	
	Return New Structure("Result, Messages, Question", Result, Messages, Question);
	
EndFunction 

&AtClient
Procedure AfterQueryClose(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		CheckRestrictionsEnd(True, AdditionalParameters.CloseForm);
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure CheckRestrictionsEnd(ShouldSave, CloseForm, ResultData = Undefined)
	
	If ShouldSave Then
		
		SaveAtServer();
		
		NewElement = New Structure;
		NewElement.Insert("Period"			, Period);
		NewElement.Insert("Company"			, Company);
		NewElement.Insert("TypeOfAccounting", TypeOfAccounting);
		
		If CloseForm Then
			
			Close(NewElement);
			
		Else
			
			Notify("NewElementCreated", NewElement);
			
		EndIf;
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure CheckRestrictions(CloseForm)

	ResultData = CheckRestrictionsAtServer();
	Result = ResultData.Result;
	
	ClearMessages();
	
	If Not Result Then
		
		For Each Message In ResultData.Messages Do
			CommonClientServer.MessageToUser(Message.Text, , Message.Field);
		EndDo;
		
		Question = ResultData.Question;
		If ResultData.Question <> Undefined Then
			
			Mode = QuestionDialogMode[Question.Buttons];
			Notification = New NotifyDescription("AfterQueryClose", ThisObject, New Structure("CloseForm", CloseForm));
			ShowQueryBox(Notification, Question.Message, Mode, 0);
			
		Else
			
			CheckRestrictionsEnd(Result, CloseForm, ResultData);
			
		EndIf;
		
	Else
		
		CheckRestrictionsEnd(Result, CloseForm);
		
	EndIf;
	
EndProcedure 

&AtServer
Function CheckCompanyHasTypesOfAccounting()

	TypesOfAccountingTable = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(
		Company,
		Period,
		Catalogs.TypesOfAccounting.EmptyRef(),
		,
		True);
	
	TypesOfAccounting = AccountingTemplatesPosting.GetValuesArrayFromTable(TypesOfAccountingTable, "TypeOfAccounting");
	
	Return New Structure("AreTypesOfAccounting, TypesOfAccounting", TypesOfAccounting.Count() > 0, TypesOfAccounting);

EndFunction

&AtClient
Procedure CompanyOnChangeEnd(Result, AdditionalParameters) Export
	
	Attribute = AdditionalParameters.Attribute;

	If Result = DialogReturnCode.Yes Then
		
		TypeOfAccounting				 = Undefined;
		TypeOfAccountingOld				 = Undefined;

		RefreshAvailableTypesOfAccountingList();
		
		DocumentTypeList.Clear();
		
		ThisObject[Attribute + "Old"] = ThisObject[Attribute];
		
	Else
		
		ThisObject[Attribute] = ThisObject[Attribute + "Old"];
		
	EndIf;

EndProcedure

&AtClient
Procedure CheckAccountingPolicy(Attribute)
	
	Items.TypeOfAccounting.Enabled	 = True;
	Items.TypeOfAccounting.InputHint = "";
	
	TypesOfAccountingStructure = CheckCompanyHasTypesOfAccounting();
	
	FindedTypeOfAccounting = TypesOfAccountingStructure.TypesOfAccounting.Find(TypeOfAccounting);
	
	If TypesOfAccountingStructure.AreTypesOfAccounting 
		And (FindedTypeOfAccounting <> Undefined
			Or Not ValueIsFilled(TypeOfAccounting)) Then
		
		RefreshDocumentTypeListAtServer();
		
		ThisObject[Attribute + "Old"] = ThisObject[Attribute];
		
		RefreshAvailableTypesOfAccountingList();
		
		Modified = True;
	Else
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Attribute", Attribute);
		
		Notification	= New NotifyDescription("CompanyOnChangeEnd", ThisObject, AdditionalParameters);
		Mode			= QuestionDialogMode.YesNo;
		
		If TypesOfAccountingStructure.AreTypesOfAccounting Then
			QueryMessageTemplate = NStr("en = 'For the selected company ""%1"", the accounting policy states that %3 is not applicable on %2.
				|The ""Type of accounting"" field and checkboxes in the document list will be cleared. 
				|Continue?'; 
				|ru = 'Для выбранной организации ""%1"" в учетной политике указано, что %3 не применяется на %2.
				|Поле ""Тип бухгалтерского учета"" и флажки в списке документов будут очищены.
				| Продолжить?';
				|pl = 'Dla wybranej firmy ""%1"", polityka rachunkowości stanowi, że %3 nie ma zastosowania na %2. 
				|Pole ""Typ rachunkowości"" i pole wyboru na liście dokumentów zostaną wyczyszczone. 
				|Kontynuować?';
				|es_ES = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %3 no es aplicable en%2.
				| El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán. 
				|¿Continuar?';
				|es_CO = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que %3 no es aplicable en%2.
				| El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán. 
				|¿Continuar?';
				|tr = 'Seçilen ""%1"" iş yeri için, muhasebe politikasına göre %3, %2''de uygulanamaz. 
				|Belge listesindeki ""Muhasebe türü"" alanı ve onay kutuları temizlenecek. 
				|Devam edilsin mi?';
				|it = 'Per l''azienda ""%1"" selezionata, la politica contabile indica che %3 non è applicabile a %2.
				|Il campo ""Tipo di contabilità"" e le caselle di controllo nell''elenco del documento saranno eliminati.
				| Continuare?';
				|de = 'Für die ausgewählte Firma ""%1"", bestimmen die Bilanzierungsrichtlinien dass %3 für %2 nicht verwendbar ist. 
				|Das Feld ""Typ der Buchhaltung"" und die Kontrollkästchen in der Dokumentenliste werden gelöscht. 
				|Weiter?'");
			QueryMessageText = StrTemplate(QueryMessageTemplate, Company, Format(Period, "DLF=D"), TypeOfAccounting);
		Else
			QueryMessageTemplate = NStr("en = 'For the selected company ""%1"", the accounting policy states that no type of accounting is applicable on %2.
				|The ""Type of accounting"" field and checkboxes in the document list will be cleared.
				|Continue?'; 
				|ru = 'Для выбранной организации ""%1"" в учетной политике указано, что ни один тип бухгалтерского учета не применяется на %2.
				|Поле ""Тип бухгалтерского учета"" и флажки в списке документов будут очищены.
				| Продолжить?';
				|pl = 'Dla wybranej firmy ""%1"", polityka rachunkowości stanowi, że nie ma typu rachunkowości, który ma zastosowanie na %2. 
				|Pole ""Typ rachunkowości"" i pole wyboru na liście dokumentów zostaną wyczyszczone. 
				|Kontynuować?';
				|es_ES = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que no se aplica ningún tipo de contabilidad en %2. 
				|El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán. 
				|¿Continuar?';
				|es_CO = 'Para la empresa seleccionada ""%1"", la política de contabilidad establece que no se aplica ningún tipo de contabilidad en %2. 
				|El campo ""Tipo de contabilidad"" y las casillas de verificación de la lista de documentos se desmarcarán. 
				|¿Continuar?';
				|tr = 'Seçilen ""%1"" iş yeri için, muhasebe politikasına göre %2''de uygulanabilecek hiç muhasebe türü yok. 
				|Belge listesindeki ""Muhasebe türü"" alanı ve onay kutuları temizlenecek. 
				|Devam edilsin mi?';
				|it = 'Per l''azienda ""%1"" selezionata,  la politica contabile indica che nessun tipo di contabilità è applicabile a %2.
				| il campo ""Tipo di contabilità"" e le caselle di controllo nell''elenco del documento saranno eliminati.
				|Continuare?';
				|de = 'Für die ausgewählte Firma ""%1"", bestimmen die Bilanzierungsrichtlinien dass kein Typ der Buchhaltung für %2 verwendbar ist. 
				|Das Feld ""Typ der Buchhaltung"" und die Kontrollkästchen in der Dokumentenliste werden gelöscht. 
				|Weiter?'");
			QueryMessageText = StrTemplate(QueryMessageTemplate, Company, Format(Period, "DLF=D"));
		EndIf;
		
		
		ShowQueryBox(Notification, QueryMessageText, Mode, 0);
		
	EndIf;
	
EndProcedure

&AtServer
Function IsChosenTypeOfAccountingActive(TypeOfAccounting)

	TypesOfAccountingTable = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(
		Company,
		Period,
		Catalogs.TypesOfAccounting.EmptyRef(),
		,
		True);
	
	Result = TypesOfAccountingTable.Find(TypeOfAccounting, "TypeOfAccounting");
	
	Return Result <> Undefined;

EndFunction

&AtClient
Procedure TypeOfAccountingOnChangeEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		TypeOfAccounting	= Undefined;
		TypeOfAccountingOld = Undefined;
		DocumentTypeList.Clear();
		
	Else
		
		TypeOfAccounting = TypeOfAccountingOld;
		
	EndIf;

EndProcedure

&AtClient
Procedure TypeOfAccountingRefreshEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		RefreshDocumentTypeListAtServer();
		
		TypeOfAccountingOld = TypeOfAccounting;
		
		Modified = True;
		
	Else
		
		TypeOfAccounting = TypeOfAccountingOld;
		
	EndIf;

EndProcedure

&AtServer
Procedure CheckDocumentsAfterSetDate(Result, Messages, ChosenDocumentTypes)
	
	If ChosenDocumentTypes.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	QueryText = Undefined;
	
	FirstText = True;
	For Each DocumentTypeItem In ChosenDocumentTypes Do
		
		DocumentTypeMeta = Common.MetadataObjectByID(DocumentTypeItem);
		If DocumentTypeMeta.Attributes.Find("Company") = Undefined Then
			Continue;
		Else
			
			QueryTemplate = 
			"SELECT
			|	MAX(ISNULL(AccountingTransaction.Date, DocumentData.Date)) AS Date,
			|	&DocumentTypeItemSynonym AS DocumentType
			|FROM
			|	&DocumentTable AS DocumentData
			|		LEFT JOIN Document.AccountingTransaction AS AccountingTransaction
			|		ON DocumentData.Ref = AccountingTransaction.BasisDocument
			|WHERE
			|	DocumentData.Posted
			|	AND ISNULL(AccountingTransaction.Date, DocumentData.Date) >= &Date
			|	AND DocumentData.Company = &Company";
			
			DocSynonym		= StrTemplate("""%1""", DocumentTypeItem.Synonym);
			DocTableName	= StrTemplate("Document.%1", DocumentTypeMeta.Name);
			
			QueryTemplate = StrReplace(QueryTemplate, "&DocumentTypeItemSynonym", DocSynonym);
			QueryTemplate = StrReplace(QueryTemplate, "&DocumentTable", DocTableName);
			
			If FirstText Then
				QueryText = QueryTemplate;
				FirstText = False;
			Else
				QueryText = QueryText + DriveClientServer.GetQueryUnion() + QueryTemplate;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If QueryText <> Undefined Then
		
		Query.Text = QueryText;
		Query.SetParameter("Company", Company);
		Query.SetParameter("Date"	, Period);
		
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Template = NStr("en = 'Cannot save the settings of the Accounting source documents. There are business documents posted after the selected date %1. Select %2 or later. Then try again.'; ru = 'Не удалось сохранить настройки первичных документов бухгалтерского учета. В базе содержатся коммерческие документы, проведенные после указанной даты %1. Укажите дату не ранее %2 и повторите попытку.';pl = 'Nie można zapisać zmian ustawień Źródłowych dokumentów księgowych. Istnieją dokumenty biznesowe, zatwierdzone po wybranej dacie %1. Wybierz %2 lub póćniej. Zatem spróbuj ponownie.';es_ES = 'No se puede guardar la configuración de los documentos de fuente de la contabilidad. Hay documentos comerciales contabilizados después de la fecha seleccionada %1. Seleccione %2 o posterior. Inténtelo de nuevo.';es_CO = 'No se puede guardar la configuración de los documentos de fuente de la contabilidad. Hay documentos comerciales contabilizados después de la fecha seleccionada %1. Seleccione %2 o posterior. Inténtelo de nuevo.';tr = 'Muhasebe kaynak belgelerinin ayarları kaydedilemiyor. Seçilen %1 tarihinden sonra kaydedilmiş iş belgeleri var. %2 veya daha sonraki bir tarih seçip tekrar deneyin.';it = 'Impossibile salvare le modifiche dei documenti fonte. Ci sono documenti aziendali pubblicati dopo la data selezionata %1. Selezionare %2 o dopo, poi riprovare.';de = 'Fehler beim Speichern von Änderungen der Buchhaltungsquelldokumente. Es gibt Geschäftsdokumente gebucht nach dem ausgewählten Datum%1. Wählen Sie %2 oder später aus. Dann versuchen Sie erneut.'");
			While Selection.Next() Do
				
				If ValueIsFilled(Selection.Date) Then
					
					Result = False;
					Message = New Structure;
					Message.Insert("Text"	, StrTemplate(Template, Format(Period, "DLF=D"), Format(EndOfDay(Selection.Date) + 1, "DLF=D")));
					Message.Insert("Field"	, "Period");
					Messages.Add(Message);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshAvailableTypesOfAccountingList()

	TypesTable = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(
		Company,
		Period,
		Catalogs.TypesOfAccounting.EmptyRef(),
		,
		True);
		
	AvailableTypesOfAccounting = AccountingTemplatesPosting.GetValuesArrayFromTable(TypesTable, "TypeOfAccounting");
	
	If ValueIsFilled(TypeOfAccounting)
		And AvailableTypesOfAccounting.Find(TypeOfAccounting) = Undefined Then
		AvailableTypesOfAccounting.Add(TypeOfAccounting);
	EndIf;
	
	Items.TypeOfAccounting.ChoiceList.LoadValues(AvailableTypesOfAccounting);
	
	If AvailableTypesOfAccounting.Count() = 0 And Not ValueIsFilled(TypeOfAccounting) Then
		Items.TypeOfAccounting.Enabled		= False;
		Items.TypeOfAccounting.InputHint	= NStr("en = '<No type of accounting is available>'; ru = '<Нет доступного типа бухгалтерского учета>';pl = '<Brak dostępnych typów rachunkowości>';es_ES = '<No hay ningún tipo de contabilidad disponible>';es_CO = '<No hay ningún tipo de contabilidad disponible>';tr = '<Muhasebe türü yok>';it = '<Nessun tipo di contabilità disponibile>';de = '<Kein Typ der Buchhaltung ist verfügbar>'");
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterOpenForm()

	If DocumentListIrrelevant Then
		
		Notification = New NotifyDescription("RefreshDocListQuestionEnding", ThisObject);
		QueryMessage = NStr("en = 'You are copying an item with the outdated list of Accounting source documents. Do you want to refresh the list now?'; ru = 'Вы собираетесь скопировать элемент с устаревшим списком первичных документов бухгалтерского учета. Обновить список?';pl = 'Skopiowano pozycję z nieaktualną listą Źródłowych dokumentów księgowych. Czy chcesz odświeżyć listę teraz?';es_ES = 'Está copiando un artículo con la lista de documentos de fuente de contabilidad obsoleta. ¿Quiere actualizar la lista ahora?';es_CO = 'Está copiando un artículo con la lista de documentos de fuente de contabilidad obsoleta. ¿Quiere actualizar la lista ahora?';tr = 'Eski bir Muhasebe kaynak belgeleri listesinden öğe kopyalıyorsunuz. Listeyi yenilemek ister misiniz?';it = 'Stai copiando un elemento con l''elenco scaduto dei documenti fonte di contabilità. Aggiornare adesso l''elenco?';de = 'Sie kopieren ein Element mit der veralteten Liste von Buchhaltungsquelldokumenten. Möchten Sie die Liste jetzt aktualisieren?'");
		
		ShowQueryBox(Notification, QueryMessage, QuestionDialogMode.YesNo);
		
	EndIf;

EndProcedure

&AtClient
Procedure RefreshDocListQuestionEnding(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		RefreshDocumentTypeListAtServer();
		
		DocumentListIrrelevant = False;
		IsCopy = False;
	EndIf;

EndProcedure

&AtClient
Procedure AfterClosingQuestion(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		SaveAndClose(Result);
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;

EndProcedure

#EndRegion