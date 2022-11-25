
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("ReadOnly") Then
		Items.History.ReadOnly = Parameters.ReadOnly;
	EndIf;
	
	ContactInformationKind = Parameters.ContactInformationKind;
	ContactInformationType = Parameters.ContactInformationKind.Type;
	CheckValidity = ContactInformationKind.CheckValidity;
	ContactInformationPresentation = Parameters.ContactInformationKind.Description;
	
	If TypeOf(Parameters.ContactsList) = Type("Array") Then
		For each ContactInformationRow In Parameters.ContactsList Do
			TableRow = History.Add();
			FillPropertyValues(TableRow, ContactInformationRow);
			TableRow.Type = ContactInformationType;
			TableRow.Kind = ContactInformationKind;
		EndDo;
		ThisObject.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'История изменений (%1)'; en = 'Change history (%1)'; pl = 'Historia edycji (%1)';es_ES = 'Historial de cambios (%1)';es_CO = 'Historial de cambios (%1)';tr = 'Değişiklik geçmişi (%1)';it = 'Modifica storico (%1)';de = 'Änderungshistorie (%1)'"), ContactInformationPresentation);
		Items.HistoryPresentation.Title = ContactInformationPresentation;
	Else
		Cancel = True;
	EndIf;
	EditOnlyInDialog = ContactInformationKind.EditOnlyInDialog;
	If ContactInformationKind.Type = Enums.ContactInformationTypes.Address Then
		EditFormName = "AddressInput";
	ElsIf ContactInformationKind.Type = Enums.ContactInformationTypes.Phone Then
		EditFormName = "PhoneInput";
	Else
		EditFormName = "";
		Items.HistoryPresentation.ChoiceButton = False;
	EndIf;
	
	History.Sort("ValidFrom Desc");
	
	If Parameters.Property("FromAddressEntryForm") AND Parameters.FromAddressEntryForm Then
		Items.HistorySelect.DefaultButton = True;
		ChoiceMode = Parameters.FromAddressEntryForm;
		Items.CommandBarGroup.Visible = False;
		Items.HistorySelect.Visible = True;
		Items.HistoryChange.Visible = False;
		Items.HistoryPresentation.ReadOnly = True;
		If Parameters.Property("ValidFrom") Then
			DateOnOpen = Parameters.ValidFrom;
			Filter = New Structure("ValidFrom", DateOnOpen);
			FoundRows = History.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Items.History.CurrentRow = FoundRows[0].GetID();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region HistoryFormTableItemEventHandlers

&AtClient
Procedure HistoryPresentationOnChange(Item)
	ThisObject.CurrentItem.CurrentData.FieldsValues = ContactsXMLByPresentation(ThisObject.CurrentItem.CurrentData.Presentation, ContactInformationKind);
EndProcedure

&AtClient
Procedure HistoryBeforeDeletion(Item, Cancel)
	// If there is at least one record made earlier than the one to be deleted, you can delete it.
	ValidFrom = Item.CurrentData.ValidFrom;
	If IsFirstDate(ValidFrom) Then
		Cancel = True;
	EndIf;
	If NOT Cancel Then
		AdditionalParameters = New Structure("RowID", Item.CurrentRow);
		Notification = New NotifyDescription("AfterAnswerToQuestionAboutDeletion", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, NStr("ru = 'Удалить адрес действующий с'; en = 'Remove the address valid from'; pl = 'Usuń adres ważny z';es_ES = 'Eliminar la dirección vigente desde';es_CO = 'Eliminar la dirección vigente desde';tr = 'Itibaren geçerli adresi sil';it = 'Rimuovi l''indirizzo valido dal';de = 'Löschen Sie die gültige Adresse mit'") + " " + Format(ValidFrom, "DLF=DD")+ "?", QuestionDialogMode.YesNo);
	EndIf;
	Cancel = True;
EndProcedure

&AtClient
Procedure HistoryBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	
	Cancel = True;
	If ChoiceMode Then
		GenerateData(True);
	Else
		OpenAddressEditForm(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "HistoryEffectiveFrom" Then
		If IsFirstDate(Item.CurrentData.ValidFrom) Then
			Cancel = True;
		EndIf;
		PreviousDate = Item.CurrentData.ValidFrom;
	Else
		OpenAddressEditForm(Items.History.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryOnChange(Item)
	
	If Item.CurrentItem.Name = "HistoryEffectiveFrom" Then
		Index = History.IndexOf(ThisObject.CurrentItem.CurrentData);
		ThisObject.CurrentItem.CurrentData.ValidFrom = AllowedDateOfHistory(PreviousDate, ThisObject.CurrentItem.CurrentData.ValidFrom, Index);
		History.Sort("ValidFrom Desc");
	EndIf;
EndProcedure

&AtClient
Procedure AddressHistoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If ChoiceMode Then
		GenerateData();
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryOnActivateRow(Item)
	
	Items.HistoryChange.Enabled = NOT IsFirstDate(Item.CurrentData.ValidFrom) AND NOT ThisObject.ReadOnly;
	Items.HistoryDelete.Enabled = NOT IsFirstDate(Item.CurrentData.ValidFrom) AND NOT ThisObject.ReadOnly;
	Items.HistoryContextMenuChange.Enabled = NOT IsFirstDate(Item.CurrentData.ValidFrom) AND NOT ThisObject.ReadOnly;;
	Items.HistoryContextMenuDelete.Enabled = NOT IsFirstDate(Item.CurrentData.ValidFrom) AND NOT ThisObject.ReadOnly;;
	
EndProcedure

&AtClient
Procedure ChoiceHistory(Item, RowSelected, Field, StandardProcessing)
	
	If ChoiceMode Then
		GenerateData();
	EndIf;
	
EndProcedure

&AtClient
Procedure HistoryValidFromOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	GenerateData();
EndProcedure

&AtClient
Procedure Cancel(Command)
	CloseFormWithoutSaving = True;
	Close();
EndProcedure

&AtClient
Procedure Select(Command)
	GenerateData();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateData(EnterNewAddress = False)
	
	CloseFormWithoutSaving = True;
	Result = New Structure();
	
	DateOptions = New Map;
	NoInitialDate = True;
	ValidAddress = 0;
	MinDelta = Undefined;
	CurrentCheckDate = CommonClient.SessionDate();
	For Index = 0 To History.Count() - 1 Do
		If NOT ValueIsFilled(History[Index].ValidFrom) Then
			NoInitialDate = False;
		EndIf;
		If DateOptions[History[Index].ValidFrom] = Undefined Then
			DateOptions.Insert(History[Index].ValidFrom, True);
		Else
			CommonClientServer.MessageToUser(NStr("ru='Не допускается ввод адресов с одинаковыми датами.'; en = 'Addresses with the same dates cannot be entered.'; pl = 'Niedozwolone jest wpisywanie adresów o tych samych datach.';es_ES = 'No se admite introducir las direcciones con las mismas fechas.';es_CO = 'No se admite introducir las direcciones con las mismas fechas.';tr = 'Aynı tarihlere sahip adresler girilmez.';it = 'Indirizzi con le stesse date non possono essere inseriti.';de = 'Adressen mit gleichen Daten sind nicht erlaubt.'"),, "History[" + String(Index) + "].ValidFrom");
			Return;
		EndIf;
		Delta = History[Index].ValidFrom - CurrentCheckDate;
		If Delta < 0 AND (MinDelta = Undefined OR Delta > MinDelta) Then
			MinDelta = Delta;
			ValidAddress = Index;
		EndIf;
		History[Index].IsHistoricalContactInformation = True;
		History[Index].StoreChangeHistory             = True;
	EndDo;
	
	History[ValidAddress].IsHistoricalContactInformation = False;

	If NOT EnterNewAddress AND NoInitialDate Then
		ShowMessageBox(, NStr("ru='Отсутствует адрес, действующий с даты начала ведения учета.'; en = 'Address valid from accounting start date is missing.'; pl = 'Nie ma adresu ważnego od daty rozpoczęcia księgowania.';es_ES = 'No hay dirección vigente de la fecha del inicio de la contabilidad.';es_CO = 'No hay dirección vigente de la fecha del inicio de la contabilidad.';tr = 'Kayıt başlangıç tarihinden itibaren geçerli olan adres mevcut değil.';it = 'Indirizzo valido dall''inizio della data di contabilità è mancante.';de = 'Es gibt keine Adresse, die ab dem Datum des Beginns der Abrechnung gültig ist.'"));
		Return;
	EndIf;
	
	Result.Insert("History", History);
	Result.Insert("EditOnlyInDialog", EditOnlyInDialog);
	Result.Insert("Modified", Modified);
	If ChoiceMode Then
		Result.Insert("EnterNewAddress", EnterNewAddress);
		If EnterNewAddress Then
			Result.Insert("CurrentAddress", CommonClient.SessionDate());
		Else
			Result.Insert("CurrentAddress", Items.History.CurrentData.ValidFrom);
		EndIf;
	EndIf;
	
	Close(Result);

EndProcedure

&AtClient
Procedure OpenAddressEditForm(Val SelectedRow)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ContactInformationKind", ContactInformationKind);
	OpeningParameters.Insert("FromHistoryForm", True);
	If SelectedRow = Undefined Then
		If History.Count() = 1 AND IsBlankString(History[0].Presentation) Then
			OpeningParameters.Insert("ValidFrom", Date(1, 1, 1));
		Else
			OpeningParameters.Insert("ValidFrom", CommonClient.SessionDate());
		EndIf;
		OpeningParameters.Insert("EnterNewAddress", True);
		AdditionalParameters = New Structure("New", True);
	Else
		RowData = History.FindByID(SelectedRow);
		OpeningParameters.Insert("FieldsValues", RowData.FieldsValues);
		OpeningParameters.Insert("Value",      RowData.Value);
		OpeningParameters.Insert("Presentation", RowData.Presentation);
		OpeningParameters.Insert("ValidFrom",    RowData.ValidFrom);
		OpeningParameters.Insert("Comment",   RowData.Comment);
		AdditionalParameters = New Structure("ValidFrom, New", RowData.ValidFrom, NOT ValueIsFilled(RowData.FieldsValues));
	EndIf;
	
	Notification = New NotifyDescription("AfterAddressEdit", ThisObject, AdditionalParameters);
	ContactsManagerClient.OpenContactInformationForm(OpeningParameters,, Notification);
	
EndProcedure

&AtClient
Procedure AfterAnswerToQuestionAboutDeletion(Result, AdditionalParameters) Export
	Delete = False;
	If Result = DialogReturnCode.Yes Then
		History.Delete(History.FindByID(AdditionalParameters.RowID));
	EndIf;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.HistoryEffectiveFrom.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("History.ValidFrom");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Начальное значение'; en = 'Initial value'; pl = 'Pierwotna wartość';es_ES = 'Valor inicial';es_CO = 'Valor inicial';tr = 'İlk değer';it = 'Valore iniziale';de = 'Anfangswert'"));
	
EndProcedure

&AtClient
Function AllowedDateOfHistory(OldDate, NewDate, Index)
	
	Filter = New Structure("ValidFrom", NewDate);
	FoundRows = History.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		CommonClientServer.MessageToUser(NStr("ru='Не допускается ввод адресов с одинаковыми датами.'; en = 'Addresses with the same dates cannot be entered.'; pl = 'Niedozwolone jest wpisywanie adresów o tych samych datach.';es_ES = 'No se admite introducir las direcciones con las mismas fechas.';es_CO = 'No se admite introducir las direcciones con las mismas fechas.';tr = 'Aynı tarihlere sahip adresler girilmez.';it = 'Indirizzi con le stesse date non possono essere inseriti.';de = 'Adressen mit gleichen Daten sind nicht erlaubt.'"),, "History[" + String(Index) + "].ValidFrom");
		If ValueIsFilled(OldDate) Then
			Return OldDate;
		Else
			Return CommonClient.SessionDate();
		EndIf;
	EndIf;
	
	Return NewDate;
EndFunction

&AtClient
Procedure AfterAddressEdit(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	If AdditionalParameters.New Then
		
		ValidFrom = ClosingResult.ValidFrom;
		Filter = New Structure("ValidFrom", ValidFrom);
		FoundRows = History.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Row = FoundRows[0];
		Else
			Row = History.Insert(0);
		EndIf;
		
		Row.ValidFrom = ClosingResult.ValidFrom;
		Row.FieldsValues = ClosingResult.ContactInformation;
		Row.Value      = ClosingResult.Value;
		Row.Presentation = ClosingResult.Presentation;
		Row.Comment = ClosingResult.Comment;
		Row.Kind = ClosingResult.Kind;
		Row.Type = ClosingResult.Type;
		Row.StoreChangeHistory = True;
		Items.History.CurrentRow = Row.GetID();;
		Items.History.CurrentItem = Items.History.ChildItems.HistoryPresentation;
		History.Sort("ValidFrom Desc");
	Else
		ValidFrom = AdditionalParameters.ValidFrom;
		Filter = New Structure("ValidFrom", ValidFrom);
		FoundRows = History.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			FoundRows[0].Presentation = ClosingResult.Presentation;
			FoundRows[0].FieldsValues = ClosingResult.ContactInformation;
			FoundRows[0].Comment = ClosingResult.Comment;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Function IsFirstDate(ValidFrom)
	
	For each HistoryRow In History Do
		If HistoryRow.ValidFrom < ValidFrom Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtServer
Function ContactsXMLByPresentation(Text, ContactInformationKind)
	
	Return ContactsManager.ContactsByPresentation(Text, ContactInformationKind);
	
EndFunction

#EndRegion