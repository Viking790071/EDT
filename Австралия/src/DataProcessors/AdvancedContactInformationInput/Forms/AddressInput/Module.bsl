// The form is parameterized:
//
//      Title - String - a form title.
//      FieldsValues - String - a serialized contacts value, or an empty string used to enter a new 
//                                one.
//      Presentation - String - address presentation (used only when working with old data).
//      ContactsKind - CatalogRef. ContactsKinds, Structure - details of what we are editing.
//                                
//      Comment - String - an optional comment to be placed in the Comment field.
//
//      ReturnsValueList - Boolean - an optional flag of a returned field value.
//                                 Contacts will have the ValueList type (compatibility).
//
//  Selection result:
//      Structure - the following fields:
//          * Contacts - String - XML of contacts.
//          * Presentation - String - presentation.
//          * Comment - String - a comment.
//          * EnteredInFreeFormat - Boolean - an input flag.
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("ru = 'Обработка не предназначена для непосредственного использования.'; en = 'Data processor is not intended for direct usage.'; pl = 'Procesor danych nie jest przeznaczony do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanım için uygun değildir.';it = 'L''elaborazione dati non è indicata per l''uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	// Form settings
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	MainCountry           = MainCountry();
	ContactInformationKind  = ContactsManagerInternal.ContactInformationKindStructure(Parameters.ContactInformationKind);
	OnCreateAtServerStoreChangeHistory();
	
	Title = ?(IsBlankString(Parameters.Title), ContactInformationKind.Description, Parameters.Title);
	
	HideObsoleteAddresses  = ContactInformationKind.HideObsoleteAddresses;
	OnlyNationalAddress     = ContactInformationKind.OnlyNationalAddress;
	ContactInformationType     = ContactInformationKind.Type;
	
	// Attempting to fill data based on parameter values.
	FieldsValues = DefineAddressValue(Parameters);
	
	If IsBlankString(FieldsValues) Then
		LocalityDetailed = ContactsManager.NewContactInformationDetails(Enums.ContactInformationTypes.Address); // New address
		LocalityDetailed.AddressType = ContactsManagerClientServer.AddressInFreeForm();
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(FieldsValues) Then
		AddressData = ContactsManagerInternal.JSONStringToStructure(FieldsValues);
		LocalityDetailed = PrepareAddressForInput(AddressData);
	Else
		XDTOContact = ExtractObsoleteAddressFormat(FieldsValues, ContactInformationType);
		AddressData = ContactsManagerInternal.ContactInformationToJSONStructure(XDTOContact, ContactInformationType);
		LocalityDetailed = PrepareAddressForInput(AddressData);
	EndIf;
	
	SetAttributeValueByContacts();
	
	SetFormUsageKey();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningTextOnOpen) Then
		CommonClientServer.MessageToUser(WarningTextOnOpen,, WarningFieldOnOpen);
	EndIf;
	
	ShowFieldsByAddressType();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CountryOnChange(Item)
	
	ShowFieldsByAddressType();
	
EndProcedure

&AtClient
Procedure CountryClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CountryAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	If DataGetParameters = 0 Then
		// Generating the quick selection list.
		If IsBlankString(Text) Then
			ChoiceData = New ValueList;
		EndIf;
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure CountryTextInputEnd(Item, Text, ChoiceData, DataGetParameters)
	
	If IsBlankString(Text) Then
		DataGetParameters = False;
	EndIf;
	
#If WebClient Then
	// Addressing platform specifics.
	DataGetParameters = False;
	ChoiceData         = New ValueList;
	ChoiceData.Add(Country);
#EndIf

EndProcedure

&AtClient
Procedure CountryChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ContactsManagerClient.WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	LocalityDetailed.Comment = Comment;
	
EndProcedure

&AtClient
Procedure AddressLine1OnChange(Item)
	LocalityDetailed.AddressLine1 = AddressLine1;
EndProcedure

&AtClient
Procedure AddressLine2OnChange(Item)
	LocalityDetailed.AddressLine2 = AddressLine2;
EndProcedure

&AtClient
Procedure CityOnChange(Item)
	LocalityDetailed.City = City;
EndProcedure

&AtClient
Procedure StateOnChange(Item)
	LocalityDetailed.State = State;
EndProcedure

&AtClient
Procedure PostalCodeOnChange(Item)
	LocalityDetailed.PostalCode = PostalCode;
EndProcedure

// House, premises

&AtClient
Procedure AddressOnDateAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	If StrCompare(Text, NStr("ru='начало учета'; en = 'accounting start'; pl = 'początek rachunkowości';es_ES = 'inicio de contabilidad';es_CO = 'inicio de contabilidad';tr = 'kayıt başlangıcı';it = 'inizio contabilità';de = 'Anfang der Abrechnung'")) = 0 Or IsBlankString(Text) Then
		Items.AddressOnDate.EditFormat = "";
	EndIf;
EndProcedure

&AtClient
Procedure AddressOnDateOnChange(Item)
	
	If Not EnterNewAddress Then
		
		Filter = New Structure("Kind", ContactInformationKind.Ref);
		FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		Result = DefineValidDate(AddressOnDate, FoundRows);
		
		If Result.CurrentRow <> Undefined Then
			Type = Result.CurrentRow.Type;
			AddressValidFrom = Result.ValidFrom;
			LocalityDetailed = AddressWithHistory(Result.CurrentRow.Value);
		Else
			Type = PredefinedValue("Enum.ContactInformationTypes.Address");
			AddressValidFrom = AddressOnDate;
			LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(Type);
		EndIf;
		
		If ValueIsFilled(Result.ValidTill) Then
			TextHistoricalAddress = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'действует по %1'; en = 'valid until %1'; pl = 'ważne do %1';es_ES = 'está vigente hasta %1';es_CO = 'está vigente hasta %1';tr = '%1 kadar geçerli';it = 'valido fino a %1';de = 'gültig bis %1'"), Format(Result.ValidTill - 10, "DLF=DD"));
		Else
			TextHistoricalAddress = NStr("ru = 'действует по настоящее время.'; en = 'valid until present.'; pl = 'ważny do bieżącego czasu.';es_ES = 'está vigente hasta la fecha';es_CO = 'está vigente hasta la fecha';tr = 'hala geçerli.';it = 'Valido fino ad oggi.';de = 'ist zum jetzigen Zeitpunkt gültig.'");
		EndIf;
		Items.TextAboutEffectiveDate.Title = TextHistoricalAddress;
	Else
		AddressValidFrom = AddressOnDate;
	EndIf;
	
	TextOfAccountingStart = NStr("ru = 'начало учета'; en = 'accounting start'; pl = 'początek rachunkowości';es_ES = 'inicio de contabilidad';es_CO = 'inicio de contabilidad';tr = 'kayıt başlangıcı';it = 'inizio contabilità';de = 'Anfang der Abrechnung'");
	Items.AddressOnDate.EditFormat = ?(ValueIsFilled(AddressOnDate), "", "DF='""" + TextOfAccountingStart  + """'");
	
EndProcedure

&AtServerNoContext
Function AddressWithHistory(FieldsValues)
	
	Return ContactsManagerInternal.JSONStringToStructure(FieldsValues);
	
EndFunction

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	ConfirmAndClose();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Modified = False;
	Close();
EndProcedure

&AtClient
Procedure ClearAddress(Command)
	
	ClearAddressClient();
	SetAttributeValueByContacts();
	
EndProcedure

&AtClient
Procedure ChangeHistory(Command)
	
	AdditionalParameters = New Structure;
	
	AdditionalAttributeDetails = ContactInformationAdditionalAttributeDetails;
	ContactsList = FillInContactsList(ContactInformationKind.Ref, AdditionalAttributeDetails);
	
	FormParameters = New Structure("ContactsList", ContactsList);
	FormParameters.Insert("ContactInformationKind", ContactInformationKind.Ref);
	FormParameters.Insert("ReadOnly", ThisObject.ReadOnly);
	FormParameters.Insert("FromAddressEntryForm", True);
	FormParameters.Insert("ValidFrom", AddressOnDate);
	
	NotificationOfClosure = New NotifyDescription("AfterClosingHistoryForm", ThisObject, AdditionalParameters);
	OpenForm("DataProcessor.ContactInformationInput.Form.ContactInformationHistory", FormParameters, ThisObject,,,, NotificationOfClosure);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If Modified Then // When unmodified, it works as "cancel".
		FillAddressPresentation(LocalityDetailed, ContactInformationKind);
		Context = New Structure("ContactInformationKind, LocalityDetailed, MainCountry, Country");
		FillPropertyValues(Context, ThisObject);
		Result = FlagUpdateSelectionResults(Context, ReturnValueList);
		
		// Reading contact information kind flags again.
		ContactInformationKind = Context.ContactInformationKind;
		
		Result = Result.ChoiceData;
		If ContactInformationKind.StoreChangeHistory Then
			ProcessContactsWithHistory(Result);
		EndIf;
		
		If TypeOf(Result) = Type("Structure") Then
			Result.Insert("ContactInformationAdditionalAttributeDetails", ContactInformationAdditionalAttributeDetails);
		EndIf;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	ElsIf Comment <> CommentCopy Then
		// Only the comment was modified, attempting to revert.
		Result = CommentChoiceOnlyResult(Parameters.FieldsValues, Parameters.Presentation, Comment);
		Result = Result.ChoiceData;
		
		ClearModifiedOnChoice();
#If WebClient Then
		CloseFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = CloseFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) AND IsOpen() Then
		ClearModifiedOnChoice();
		SaveFormState();
		Close(Result);
	EndIf;

EndProcedure

&AtServerNoContext
Procedure FillAddressPresentation(Address, InformationKind)
	
	If TypeOf(InformationKind) = Type("Structure") AND InformationKind.Property("IncludeCountryInPresentation") Then
		IncludeCountryInPresentation = InformationKind.IncludeCountryInPresentation;
	Else
		IncludeCountryInPresentation = False;
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		ModuleAddressManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
	Else
		ContactsManagerClientServer.UpdateAddressPresentation(Address, IncludeCountryInPresentation);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessContactsWithHistory(Result)
	
	Result.Insert("ValidFrom", ?(EnterNewAddress, AddressOnDate, AddressValidFrom));
	AttributeName = "";
	Filter = New Structure("Kind", Result.Kind);
	
	StringOfValidAddress = Undefined;
	DateWasChanged         = True;
	CurrentDateOfAddress        = CommonClient.SessionDate();
	Delta                   = AddressOnDate - CurrentDateOfAddress;
	MinDelta        = ?(Delta > 0, Delta, -Delta);
	FoundRows          = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	For Each FoundRow In FoundRows Do
		If ValueIsFilled(FoundRow.AttributeName) Then
			AttributeName = FoundRow.AttributeName;
		EndIf;
		If FoundRow.ValidFrom = AddressOnDate Then
			DateWasChanged = False;
			StringOfValidAddress = FoundRow;
			Break;
		EndIf;
		
		Delta = CurrentDateOfAddress - FoundRow.ValidFrom;
		Delta = ?(Delta > 0, Delta, -Delta);
		If Delta <= MinDelta Then
			MinDelta = Delta;
			StringOfValidAddress = FoundRow;
		EndIf;
	EndDo;
	
	If DateWasChanged Then
		
		Filter = New Structure("ValidFrom, Kind", AddressValidFrom, Result.Kind);
		StringsWithAddress = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		
		EditedAddressPresentation = ?(StringsWithAddress.Count() > 0, StringsWithAddress[0].Presentation, "");
		If StrCompare(Result.Presentation, EditedAddressPresentation) <> 0 Then
			NewContacts = ContactInformationAdditionalAttributeDetails.Add();
			FillPropertyValues(NewContacts, Result);
			NewContacts.FieldsValues           = Result.ContactInformation;
			NewContacts.Value                = Result.Value;
			NewContacts.ValidFrom              = AddressOnDate;
			NewContacts.StoreChangeHistory = True;
			If StringOfValidAddress = Undefined Then
				Filter = New Structure("IsHistoricalContactInformation, Kind", False, Result.Kind);
				FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
				For each FoundRow In FoundRows Do
					FoundRow.IsHistoricalContactInformation = True;
					FoundRow.AttributeName = "";
				EndDo;
				NewContacts.AttributeName = AttributeName;
				NewContacts.IsHistoricalContactInformation = False;
			Else
				NewContacts.IsHistoricalContactInformation = True;
				Result.Presentation                = StringOfValidAddress.Presentation;
				Result.ContactInformation         = StringOfValidAddress.FieldsValues;
				Result.Value = StringOfValidAddress.Value;
			EndIf;
		ElsIf StrCompare(Result.Comment, StringOfValidAddress.Comment) <> 0 AND StringsWithAddress.Count() > 0 Then
			// Changed only the comment.
			StringsWithAddress[0].Comment = Result.Comment;
		EndIf;
	Else
		If StrCompare(Result.Presentation, StringOfValidAddress.Presentation) <> 0
			OR StrCompare(Result.Comment, StringOfValidAddress.Comment) <> 0 Then
				FillPropertyValues(StringOfValidAddress, Result);
				StringOfValidAddress.FieldsValues                       = Result.ContactInformation;
				StringOfValidAddress.Value                            = Result.Value;
				StringOfValidAddress.AttributeName                        = AttributeName;
				StringOfValidAddress.IsHistoricalContactInformation = False;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure AfterClosingHistoryForm(Result, AdditionalParameters) Export

	If Result = Undefined Then
		Return;
	EndIf;
	
	EnterNewAddress = ?(Result.Property("EnterNewAddress"), Result.EnterNewAddress, False);
	If EnterNewAddress Then
		AddressValidFrom = AddressOnDate;
		AddressOnDate = Result.CurrentAddress;
		LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	Else
		Filter = New Structure("Kind", ContactInformationKind.Ref);
		FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		
		AttributeName = "";
		For Each ContactInformationRow In FoundRows Do
			If NOT ContactInformationRow.IsHistoricalContactInformation Then
				AttributeName = ContactInformationRow.AttributeName;
			EndIf;
			ContactInformationAdditionalAttributeDetails.Delete(ContactInformationRow);
		EndDo;
		
		IsHistoricalContactInformation = False;
		UpdateParameters = New Structure;
		For Each ContactInformationRow In Result.History Do
			RowData = ContactInformationAdditionalAttributeDetails.Add();
			FillPropertyValues(RowData, ContactInformationRow);
			If NOT ContactInformationRow.IsHistoricalContactInformation Then
				RowData.AttributeName = AttributeName;
			EndIf;
			If BegOfDay(Result.CurrentAddress) = BegOfDay(ContactInformationRow.ValidFrom) Then
				AddressOnDate = Result.CurrentAddress;
				LocalityDetailed = JSONStringToStructure(ContactInformationRow.Value);
				
			EndIf;
		EndDo;
	EndIf;
	
	ShowInformationAboutAddressValidityDate(AddressOnDate);
	
	If NOT ThisObject.Modified Then
		ThisObject.Modified = Result.Modified;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JSONStringToStructure(Value)
	Return ContactsManagerInternal.JSONStringToStructure(Value);
EndFunction

&AtClient
Procedure SaveFormState()
	SetFormUsageKey();
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	Modified = False;
	CommentCopy   = Comment;
EndProcedure

&AtServerNoContext
Function FlagUpdateSelectionResults(Context, ReturnValueList = False)
	// Updating some flags
	FlagsValue = ContactsManagerInternal.ContactInformationKindStructure(Context.ContactInformationKind.Ref);
	
	Context.ContactInformationKind.OnlyNationalAddress = FlagsValue.OnlyNationalAddress;
	Context.ContactInformationKind.CheckValidity   = FlagsValue.CheckValidity;

	Return SelectionResult(Context, ReturnValueList);
EndFunction

&AtServerNoContext
Function SelectionResult(Context, ReturnValueList = False)

	LocalityDetailed = Context.LocalityDetailed;
	Result      = New Structure("ChoiceData, FillingErrors");
	
	ChoiceData = LocalityDetailed;
	
	Result.ChoiceData = New Structure;
	Result.ChoiceData.Insert("ContactInformation", 
		ContactsManagerInternal.ContactsFromJSONToXML(ChoiceData, Context.ContactInformationKind.Type));
	Result.ChoiceData.Insert("Value", ContactsManagerInternal.ToJSONStringStructure(ChoiceData));
	Result.ChoiceData.Insert("Presentation", LocalityDetailed.Value);
	Result.ChoiceData.Insert("Comment", LocalityDetailed.Comment);
	Result.ChoiceData.Insert("EnteredInFreeFormat",
		ContactsManagerInternal.AddressEnteredInFreeFormat(LocalityDetailed));
		
	// filling error
	Result.FillingErrors = New Array;
		
	If Context.ContactInformationKind.Type = Enums.ContactInformationTypes.Address 
		AND Context.ContactInformationKind.EditOnlyInDialog Then
			AddressAsHyperlink = True;
	Else
			AddressAsHyperlink = False;
	EndIf;
	Result.ChoiceData.Insert("AddressAsHyperlink", AddressAsHyperlink);
	
	// Suppressing line breaks in the separately returned presentation.
	Result.ChoiceData.Presentation = TrimAll(StrReplace(Result.ChoiceData.Presentation, Chars.LF, " "));
	Result.ChoiceData.Insert("Kind", Context.ContactInformationKind.Ref);
	Result.ChoiceData.Insert("Type", Context.ContactInformationKind.Type);
	
	Return Result;
EndFunction

&AtServerNoContext
Function FillInContactsList(ContactInformationKind, ContactInformationAdditionalAttributeDetails)

	Filter = New Structure("Kind", ContactInformationKind);
	FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	
	ContactsList = New Array;
	For each ContactInformationRow In FoundRows Do
		ContactInformation = New Structure("Presentation, Value, FieldsValues, ValidFrom, Comment");
		FillPropertyValues(ContactInformation, ContactInformationRow);
		ContactsList.Add(ContactInformation);
	EndDo;
	
	Return ContactsList;
EndFunction

&AtServer
Function CommentChoiceOnlyResult(ContactInfo, Presentation, Comment)
	
	If IsBlankString(ContactInfo) Then
		NewContactInfo = ContactsManagerInternal.XMLAddressInXDTO("");
		NewContactInfo.Comment = Comment;
		NewContactInfo = ContactsManagerInternal.XDTOContactsInXML(NewContactInfo);
		AddressEnteredInFreeFormat = False;
		
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInfo) Then
		// Copy
		NewContactInfo = ContactInfo;
		// Modifying NewContactInfo value.
		ContactsManager.SetContactInformationComment(NewContactInfo, Comment);
		AddressEnteredInFreeFormat = ContactsManagerInternal.AddressEnteredInFreeFormat(ContactInfo);
		
	Else
		NewContactInfo = ContactInfo;
		AddressEnteredInFreeFormat = False;
	EndIf;
	
	Result = New Structure("ChoiceData, FillingErrors", New Structure, New ValueList);
	Result.ChoiceData.Insert("ContactInformation", NewContactInfo);
	Result.ChoiceData.Insert("Presentation", Presentation);
	Result.ChoiceData.Insert("Comment", Comment);
	Result.ChoiceData.Insert("EnteredInFreeFormat", AddressEnteredInFreeFormat);
	Return Result;
EndFunction

&AtClient
Procedure ShowFieldsByAddressType()
	
	IsNationalAddress            = (Country = MainCountry);
	
	LocalityDetailed.Country = TrimAll(Country);
	
	If ContactInformationKind.IncludeCountryInPresentation Then
		UpdateAddressPresentation();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAttributeValueByContacts()
	
	FillPropertyValues(ThisObject, LocalityDetailed);
	
	// Common attributes
	ThisObject.AddressPresentation = LocalityDetailed.Value;
	If LocalityDetailed.Property("Comment") Then
		ThisObject.Comment         = LocalityDetailed.Comment;
	EndIf;
	
	// Comment copy used to identify data modifications.
	ThisObject.CommentCopy = ThisObject.Comment;
	
	RefToMainCountry = MainCountry();
	CountryData = Undefined;
	If LocalityDetailed.Property("Country") AND ValueIsFilled(LocalityDetailed.Country) Then
		CountryData = Catalogs.WorldCountries.WorldCountryData(, TrimAll(LocalityDetailed.Country));
	EndIf;
	
	If CountryData = Undefined Then
		// Country data is found neither in the catalog nor in the ARCC.
		ThisObject.Country    = RefToMainCountry;
		ThisObject.CountryCode = RefToMainCountry.Code;
	Else
		ThisObject.Country    = CountryData.Ref;
		ThisObject.CountryCode = CountryData.Code;
	EndIf;
		
	ThisObject.AddressPresentation = LocalityDetailed.Value;
	
EndProcedure

&AtServer
Procedure DeleteItemGroup(Folder)
	While Folder.ChildItems.Count()>0 Do
		Item = Folder.ChildItems[0];
		If TypeOf(Item)=Type("FormGroup") Then
			DeleteItemGroup(Item);
		EndIf;
		Items.Delete(Item);
	EndDo;
	Items.Delete(Folder);
EndProcedure

&AtServer
Procedure ShowInformationAboutAddressValidityDate(ValidFrom)
	
	If EnterNewAddress Then
		TextHistoricalAddress = "";
		AddressOnDate = ValidFrom;
		Items.HistoricalAddressGroup.Visible = ValueIsFilled(ValidFrom);
	Else
		ValidTo = Undefined;
		
		Filter = New Structure("Kind", ContactInformationKind.Ref);
		FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		If FoundRows.Count() = 0 
			OR (FoundRows.Count() = 1 AND IsBlankString(FoundRows[0].Presentation)) Then
				AddressOnDate = Date(1, 1, 1);
				Items.HistoricalAddressGroup.Visible = False;
				Items.ChangeHistory.Visible = False;
		Else
			Result = DefineValidDate(ValidFrom, FoundRows);
			AddressOnDate = Result.ValidFrom;
			AddressValidFrom = Result.ValidFrom;
			
			If NOT ValueIsFilled(Result.ValidFrom)
				AND IsBlankString(Result.CurrentRow.Presentation) Then
					Items.HistoricalAddressGroup.Visible = False;
			ElsIf ValueIsFilled(Result.ValidTill) Then
				TextHistoricalAddress = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'действует по %1'; en = 'valid until %1'; pl = 'ważne do %1';es_ES = 'está vigente hasta %1';es_CO = 'está vigente hasta %1';tr = '%1 kadar geçerli';it = 'valido fino a %1';de = 'gültig bis %1'"), Format(Result.ValidTill - 10, "DLF=DD"));
			Else
				TextHistoricalAddress = NStr("ru = 'действует по настоящее время.'; en = 'valid until present.'; pl = 'ważny do bieżącego czasu.';es_ES = 'está vigente hasta la fecha';es_CO = 'está vigente hasta la fecha';tr = 'hala geçerli.';it = 'Valido fino ad oggi.';de = 'ist zum jetzigen Zeitpunkt gültig.'");
			EndIf;
			ShowRecordsCountInHistoryChange();
		EndIf;
	EndIf;
	
	Items.TextAboutEffectiveDate.Title = TextHistoricalAddress;
	Items.AddressOnDate.EditFormat = ?(ValueIsFilled(AddressOnDate), "", "DF='""" + NStr("ru='начало учета'; en = 'accounting start'; pl = 'początek rachunkowości';es_ES = 'inicio de contabilidad';es_CO = 'inicio de contabilidad';tr = 'kayıt başlangıcı';it = 'inizio contabilità';de = 'Anfang der Abrechnung'") + """'");
	
EndProcedure

&AtServer
Procedure ShowRecordsCountInHistoryChange()
	
	Filter = New Structure("Kind", ContactInformationKind.Ref);
	FoundRows = ContactInformationAdditionalAttributeDetails.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		Items.ChangeHistoryHyperlink.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='История изменений (%1)'; en = 'Change history (%1)'; pl = 'Historia edycji (%1)';es_ES = 'Historial de cambios (%1)';es_CO = 'Historial de cambios (%1)';tr = 'Değişiklik geçmişi (%1)';it = 'Modifica storico (%1)';de = 'Änderungshistorie (%1)'"), FoundRows.Count());
		Items.ChangeHistoryHyperlink.Visible = True;
	ElsIf FoundRows.Count() = 1 AND IsBlankString(FoundRows[0].FieldsValues) Then
		Items.ChangeHistoryHyperlink.Visible = False;
	Else
		Items.ChangeHistoryHyperlink.Title = NStr("ru='История изменений'; en = 'Change history'; pl = 'Historia zmian';es_ES = 'Cambiar historia';es_CO = 'Cambiar historia';tr = 'Değişiklik geçmişi';it = 'Modificare storico';de = 'Geschichte der Änderungen'");
		Items.ChangeHistoryHyperlink.Visible = True;
	EndIf;

EndProcedure

&AtClientAtServerNoContext
Function DefineValidDate(ValidFrom, History)
	
	Result = New Structure("ValidTill, ValidFrom, CurrentRow");
	If History.Count() = 0 Then
		Return Result;
	EndIf;
	
	CurrentRow        = Undefined;
	ValidTill          = Undefined;
	Min              = -1;
	MinComparative = Undefined;
	
	For each HistoryString In History Do
		Delta = HistoryString.ValidFrom - ValidFrom;
		If Delta <= 0 AND (MinComparative = Undefined OR Delta > MinComparative) Then
			CurrentRow        = HistoryString;
			MinComparative = Delta;
		EndIf;

		If Min = -1 Then
			Min       = Delta + 1;
			CurrentRow = HistoryString;
		EndIf;
		If Delta > 0 AND ModuleNumbers(Delta) < ModuleNumbers(Min) Then
			ValidTill = HistoryString.ValidFrom;
			Min     = ModuleNumbers(Delta);
		EndIf;
	EndDo;
	
	Result.ValidTill   = ValidTill;
	Result.ValidFrom    = CurrentRow.ValidFrom;
	Result.CurrentRow = CurrentRow;
	
	Return Result;
EndFunction

&AtClientAtServerNoContext
Function ModuleNumbers(Number)
	Return Max(Number, -Number);
EndFunction

&AtClient
Procedure ClearAddressClient()
	
	For each AddressItem In LocalityDetailed Do
		
		If AddressItem.Key = "Type" Then
			Continue;
		ElsIf AddressItem.Key = "Buildings"  OR AddressItem.Key = "Apartments" Then
			LocalityDetailed[AddressItem.Key] = New Array;
		Else
			LocalityDetailed[AddressItem.Key] = "";
		EndIf;
		
	EndDo;
	
	If ContactInformationKind.OnlyNationalAddress Then
		LocalityDetailed.Country = MainCountry();
	EndIf;
	
	LocalityDetailed.AddressType = ContactsManagerClientServer.AddressInFreeForm();
	
EndProcedure

&AtServer
Procedure SetFormUsageKey()
	WindowOptionsKey = String(Country);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServer
Procedure OnCreateAtServerStoreChangeHistory()
	
	If ContactInformationKind.StoreChangeHistory Then
		If Parameters.Property("ContactInformationAdditionalAttributeDetails") Then
			For each CIRow In Parameters.ContactInformationAdditionalAttributeDetails Do
				NewRow = ContactInformationAdditionalAttributeDetails.Add();
				FillPropertyValues(NewRow, CIRow);
			EndDo;
		Else
			Items.ChangeHistory.Visible           = False;
		EndIf;
		Items.ChangeHistoryHyperlink.Visible = NOT Parameters.Property("FromHistoryForm");
		EnterNewAddress = ?(Parameters.Property("EnterNewAddress"), Parameters.EnterNewAddress, False);
		If EnterNewAddress Then
			ValidFrom = Parameters.ValidFrom;
		Else
			ValidFrom = ?(ValueIsFilled(Parameters.ValidFrom), Parameters.ValidFrom, CurrentSessionDate());
		EndIf;
		ShowInformationAboutAddressValidityDate(ValidFrom);
	Else
		Items.ChangeHistory.Visible           = False;
		Items.HistoricalAddressGroup.Visible    = False;
	EndIf;

EndProcedure

&AtServer
Function DefineAddressValue(Parameters)
	
	If Parameters.Property("Value") Then
		If IsBlankString(Parameters.Value) AND ValueIsFilled(Parameters.FieldsValues) Then
			FieldsValues = Parameters.FieldsValues;
		Else
			FieldsValues = Parameters.Value;
		EndIf;
	Else
		FieldsValues = Parameters.FieldsValues;
	EndIf;
	Return FieldsValues;

EndFunction

&AtServer
Function ExtractObsoleteAddressFormat(Val FieldsValues, Val ContactInformationType)
	
	Var XDTOContact, ReadResults;
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues)
		AND ContactInformationType = Enums.ContactInformationTypes.Address Then
		ReadResults = New Structure;
		XDTOContact = ContactsManagerInternal.ContactsFromXML(FieldsValues, ContactInformationType, ReadResults);
		If ReadResults.Property("ErrorText") Then
			// Recognition errors. A warning must be displayed when opening the form.
			WarningTextOnOpen = ReadResults.ErrorText;
			XDTOContact.Presentation   = Parameters.Presentation;
			XDTOContact.Content.Country   = String(MainCountry);
		EndIf;
	Else
		XDTOContact = ContactsManagerInternal.XMLAddressInXDTO(FieldsValues, Parameters.Presentation, );
		If Parameters.Property("Country") AND ValueIsFilled(Parameters.Country) Then
			If TypeOf(Parameters.Country) = TypeOf(Catalogs.WorldCountries.EmptyRef()) Then
				XDTOContact.Content.Country = Parameters.Country.Description;
			Else
				XDTOContact.Content.Country = String(Parameters.Country);
			EndIf;
		Else
			XDTOContact.Content.Country = MainCountry.Description;
		EndIf;
	EndIf;
	If Parameters.Comment <> Undefined Then
		// Creating a new comment to prevent comment import from contact information.
		XDTOContact.Comment = Parameters.Comment;
	EndIf;
	Return XDTOContact;

EndFunction

&AtClient
Procedure UpdateAddressPresentation()
	AddressPresentation = LocalityDetailed.Value;
EndProcedure

&AtServerNoContext
Function MainCountry()
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Return ModuleAddressManagerClientServer.MainCountry();
		
	EndIf;
	
	Return Catalogs.WorldCountries.EmptyRef();

EndFunction

&AtServer
Function PrepareAddressForInput(Data)
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		LocalityDetailed = ModuleAddressManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	Else
		LocalityDetailed = ContactsManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	EndIf;
	
	FillPropertyValues(LocalityDetailed, Data);
	
	IsEmptyAddress = True;
	
	For each AddressItem In LocalityDetailed Do
		
		If StrEndsWith(AddressItem.Key, "ID")
			AND TypeOf(AddressItem.Value) = Type("String")
			AND StrLen(AddressItem.Value) = 36 Then
				LocalityDetailed[AddressItem.Key] = New UUID(AddressItem.Value);
		EndIf;
			
		If ValueIsFilled(AddressItem.Value)
			AND NOT AddressItem.Key = "AddressType"
			AND NOT AddressItem.Key = "type"
			AND NOT AddressItem.Key = "value" Then
				IsEmptyAddress = False;
		EndIf;
		
	EndDo;
	
	If IsEmptyAddress Then
		LocalityDetailed.AddressLine1 = LocalityDetailed.value;
	EndIf;
	
	Return LocalityDetailed;
	
EndFunction

#EndRegion