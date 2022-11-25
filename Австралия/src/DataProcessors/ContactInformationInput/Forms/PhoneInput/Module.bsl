// The form is parameterized:
//
//      Title - String - a form title.
//      FieldsValues - String - a serialized contact information value or an empty string used to 
//                                enter a new one.
//      Presentation - String - an address presentation (used only when working with old data).
//      ContactsKind - CatalogRef. ContactsKinds, Structure - details of what we are editing.
//                                
//      Comment - String - an optional comment to be placed in the Comment field.
//
//      ReturnsValueList - Boolean - an optional flag of a returned field value.
//                                 ContactInformation will have the ValueList type (compatibility).
//
//  Selection result:
//      Structure - the following fields:
//          * ContactInformation - String - contact information XML.
//          * Presentation - String - a presentation.
//          * Сomment - String - a comment.
//
// -------------------------------------------------------------------------------------------------

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	// Copying parameters to attributes.
	If TypeOf(Parameters.ContactInformationKind) = Type("CatalogRef.ContactInformationKinds") Then
		ContactInformationKind = Parameters.ContactInformationKind;
		ContactInformationType = ContactInformationKind.Type;
	Else
		ContactsKindStructure = Parameters.ContactInformationKind;
		ContactInformationType = ContactsKindStructure.Type;
	EndIf;
	
	CheckValidity      = ContactInformationKind.CheckValidity;
	Title = ?(IsBlankString(Parameters.Title), String(ContactInformationKind), Parameters.Title);
	IsNew = False;
	
	FieldsValues = DefineAddressValue(Parameters);
	
	If IsBlankString(FieldsValues) Then
		Data = ContactsManager.NewContactInformationDetails(ContactInformationType);
		IsNew = True;
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(FieldsValues) Then
		Data = ContactsManagerInternal.JSONStringToStructure(FieldsValues);
	Else
		
		If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
			ReadResults = New Structure;
			ContactInformation = ContactsManagerInternal.ContactsFromXML(FieldsValues, ContactInformationType, ReadResults);
			If ReadResults.Property("ErrorText") Then
				// Recognition errors. A warning must be displayed when opening the form.
				WarningTextOnOpen = ReadResults.ErrorText;
				ContactInformation.Presentation   = Parameters.Presentation;
			EndIf;
		Else
			If ContactInformationType = Enums.ContactInformationTypes.Phone Then
				ContactInformation = ContactsManagerInternal.PhoneDeserialization(FieldsValues, Parameters.Presentation, ContactInformationType);
			Else
				ContactInformation = ContactsManagerInternal.FaxDeserialization(FieldsValues, Parameters.Presentation, ContactInformationType);
			EndIf;
		EndIf;
		
		Data = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation, ContactInformationType);
		
	EndIf;
	
	ContactInformationAttibuteValues(Data);
	
	Items.Extension.Visible = ContactInformationKind.PhoneWithExtension;
	Items.ClearPhone.Visible = False;
	
	Codes = Common.CommonSettingsStorageLoad("DataProcessor.ContactInformationInput.Form.PhoneInput", "CountryAndCityCodes");
	If TypeOf(Codes) = Type("Structure") Then
		If IsNew Then
				Codes.Property("CountryCode", CountryCode);
				Codes.Property("CityCode", CityCode);
		EndIf;
		
		If Codes.Property("CityCodesList") Then
			Items.CityCode.ChoiceList.LoadValues(Codes.CityCodesList);
		EndIf;
	EndIf;
	
	If ContactInformationKind.StoreChangeHistory Then
		If Parameters.Property("ContactInformationAdditionalAttributeDetails") Then
			For each CIRow In Parameters.ContactInformationAdditionalAttributeDetails Do
				NewRow = ContactInformationAdditionalAttributeDetails.Add();
				FillPropertyValues(NewRow, CIRow);
			EndDo;
		EndIf;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		CommonClientServer.SetFormItemProperty(Items, "Presentation", "InputHint",	NStr("ru ='Представление'; en = 'Presentation'; pl = 'Przedstawienie';es_ES = 'Presentación';es_CO = 'Presentación';tr = 'Sunum';it = 'Presentazione';de = 'Präsentation'"));
		CommonClientServer.SetFormItemProperty(Items, "OkCommand",		"Picture",			PictureLib.WriteAndClose);
		CommonClientServer.SetFormItemProperty(Items, "OkCommand",		"Representation",		ButtonRepresentation.Picture);
		CommonClientServer.SetFormItemProperty(Items, "Cancel",		"Visible",		False);
		
		CommonClientServer.SetFormItemProperty(Items, "CountryCode",		"TitleLocation", FormItemTitleLocation.Left);
		CommonClientServer.SetFormItemProperty(Items, "CityCode",		"TitleLocation", FormItemTitleLocation.Left);
		CommonClientServer.SetFormItemProperty(Items, "PhoneNumber",	"TitleLocation", FormItemTitleLocation.Left);
		CommonClientServer.SetFormItemProperty(Items, "Extension",	"TitleLocation", FormItemTitleLocation.Left);
		
		If Items.CityCode.ChoiceList.Count() < 2 Then
			
			Items.CityCode.DropListButton = Undefined;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(WarningTextOnOpen) Then
		AttachIdleHandler("Attachable_WarnAfterOpenForm", 0.1, True);
	EndIf;
	
	If ValueIsFilled(CityCode) Then
		CurrentItem = Items.CityCode;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CountryCodeOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure AreaCodeOnChange(Item)
	
	If (CountryCode = "+7" OR CountryCode = "8") AND StrStartsWith(CityCode, "9") AND StrLen(CityCode) <> 3 Then
		CommonClientServer.MessageToUser(NStr("ru = 'Кода мобильных телефонов начинающиеся на цифру 9 имеют фиксированную длину в 3 цифры, например - 916.'; en = 'Codes of cell phones beginning with 9 have a fixed length of 3 numbers. For example, 916.'; pl = 'Kody telefonów komórkowych zaczynające się od 9 mają stałą długość 3 cyfr, na przykład 916.';es_ES = 'Los códigos de los teléfonos móviles que empiezan con el número 9 tienen una longitud fija de 3 números, por ejemplo - 916.';es_CO = 'Los códigos de los teléfonos móviles que empiezan con el número 9 tienen una longitud fija de 3 números, por ejemplo - 916.';tr = '9 ile başlayan cep telefon numaraları 3 haneli sabit uzunluğa sahip olduğunda, örneğin 916.';it = 'I codici dei telefoni cellulari che iniziano con 9 hanno una lunghezza fissa di 3 cifre. Ad esempio, 916.';de = 'Codes von Mobiltelefonen, die mit 9 beginnen, haben eine feste Länge von 3 Ziffern, zum Beispiel - 916.'"),, "CityCode");
	EndIf;
	
	FillPhonePresentation();
EndProcedure

&AtClient
Procedure PhoneNumberOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure ExtensionOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

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
Procedure ClearPhone(Command)
	
	ClearPhoneServer();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_WarnAfterOpenForm()
	
	CommonClientServer.MessageToUser(WarningTextOnOpen);
	
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	// When unmodified, it functions as "cancel".
	
	If Modified Then
		
		HasFillingErrors = False;
		// Determining whether validation is required.
		If CheckValidity Then
			ErrorsList = PhoneFillingErrors();
			HasFillingErrors = ErrorsList.Count() > 0;
		EndIf;
		If HasFillingErrors Then
			NotifyFillErrors(ErrorsList);
			Return;
		EndIf;
		
		Result = SelectionResult();
	
		ClearModifiedOnChoice();
		NotifyChoice(Result);
		
	ElsIf Comment <> CommentCopy Then
		// Only the comment was modified, attempting to revert.
		Result = CommentChoiceOnlyResult();
		
		ClearModifiedOnChoice();
		NotifyChoice(Result);
		
	Else
		Result = Undefined;
		
	EndIf;
	
	If (ModalMode Or CloseOnChoice) AND IsOpen() Then
		ClearModifiedOnChoice();
		Close(Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearModifiedOnChoice()
	
	Modified = False;
	CommentCopy   = Comment;
	
EndProcedure

&AtServer
Function SelectionResult()
	
	Result = New Structure();
	
	ChoiceList = Items.CityCode.ChoiceList;
	ListItem = ChoiceList.FindByValue(CityCode);
	If ListItem = Undefined Then
		ChoiceList.Insert(0, CityCode);
		If ChoiceList.Count() > 10 Then
			ChoiceList.Delete(10);
		EndIf;
	Else
		Index = ChoiceList.IndexOf(ListItem);
		If Index <> 0 Then
			ChoiceList.Move(Index, -Index);
		EndIf;
	EndIf;
	
	Codes = New Structure("CountryCode, CityCode, CityCodesList", CountryCode, CityCode, ChoiceList.UnloadValues());
	Common.CommonSettingsStorageSave("DataProcessor.ContactInformationInput.Form.PhoneInput", "CountryAndCityCodes", Codes, NStr("ru = 'Коды страны и города'; en = 'Codes of country and city'; pl = 'Kody kraju i miasta';es_ES = 'Códigos de país y ciudad';es_CO = 'Códigos de país y ciudad';tr = 'Ülke ve şehir kodu';it = 'Codici di Paese e Città';de = 'Codes von Land und Stadt'"));
	
	ContactInformation = ContactInformationByAttributeValues();
	
	ChoiceData = ContactsManagerInternal.ToJSONStringStructure(ContactInformation);
	
	Result.Insert("Kind", ContactInformationKind);
	Result.Insert("Type", ContactInformationType);
	Result.Insert("ContactInformation", ContactsManager.ContactInformationToXML(ChoiceData, ContactInformation.Value, ContactInformationType));
	Result.Insert("Value", ChoiceData);
	Result.Insert("Presentation", ContactInformation.Value);
	Result.Insert("Comment", ContactInformation.Comment);
	Result.Insert("ContactInformationAdditionalAttributeDetails",
		ContactInformationAdditionalAttributeDetails);
	
	Return Result
EndFunction

&AtServer
Function CommentChoiceOnlyResult()
	
	ContactInfo = DefineAddressValue(Parameters);
	If IsBlankString(ContactInfo) Then
		If ContactInformationType = Enums.ContactInformationTypes.Phone Then
			ContactInfo = ContactsManagerInternal.PhoneDeserialization("", "", ContactInformationType);
		Else
			ContactInfo = ContactsManagerInternal.FaxDeserialization("", "", ContactInformationType);
		EndIf;
		ContactsManager.SetContactInformationComment(ContactInfo, Comment);
		ContactInfo = ContactsManager.ContactInformationToXML(ContactInfo);
		
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(ContactInfo) Then
		ContactsManager.SetContactInformationComment(ContactInfo, Comment);
	EndIf;
	
	Return New Structure("ContactInformation, Presentation, Comment",
		ContactInfo, Parameters.Presentation, Comment);
EndFunction

// Fills in form attributes based on XTDO object of the Contact information type.
&AtServer
Procedure ContactInformationAttibuteValues(InformationToEdit)
	
	// Common attributes
	Presentation = InformationToEdit.Value;
	Comment   = InformationToEdit.Comment;
	
	// Comment copy used to analyze changes.
	CommentCopy = Comment;
	
	CountryCode     = InformationToEdit.CountryCode;
	CityCode     = InformationToEdit.AreaCode;
	PhoneNumber = InformationToEdit.Number;
	Extension    = InformationToEdit.ExtNumber;
	
EndProcedure

// Returns an XTDO object of the Contact information type based on attribute values.
&AtServer
Function ContactInformationByAttributeValues()
	
	Result = ContactsManagerClientServer.NewContactInformationDetails(ContactInformationType);
	
	Result.CountryCode = CountryCode;
	Result.AreaCode    = CityCode;
	Result.Number      = PhoneNumber;
	Result.ExtNumber   = Extension;
	Result.Value       = ContactsManagerClientServer.GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, "");
	Result.Comment     = Comment;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillPhonePresentation()
	
	AttachIdleHandler("FillPhonePresentationNow", 0.1, True);
	
EndProcedure    

&AtClient
Procedure FillPhonePresentationNow()
	
	Presentation = ContactsManagerClientServer.GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment);
	
EndProcedure

// Returns a list of filling errors as a value list:
//      Presentation - error details.
//      Value - XPath for the field.
&AtClient
Function PhoneFillingErrors()
	
	ErrorsList = New ValueList;
	FullPhoneNumber = CountryCode + CityCode + PhoneNumber;
	PhoneNumberOnlyNumbersOnly = NumbersOnly(FullPhoneNumber);
	
	If StrLen(PhoneNumberOnlyNumbersOnly) > 15 Then
		ErrorsList.Add("PhoneNumber", NStr("ru = 'Номер телефона слишком длинный'; en = 'Phone number is too long'; pl = 'Zbyt długi numer telefonu';es_ES = 'Número de teléfono es demasiado largo';es_CO = 'Número de teléfono es demasiado largo';tr = 'Telefon numarası çok uzun';it = 'Il numero di telefono è troppo lungo';de = 'Die Telefonnummer ist zu lang'"));
	EndIf;
	
	If PhoneNumberContainsProhibitedChars(FullPhoneNumber) Then
		ErrorsList.Add("PhoneNumber", NStr("ru = 'Номер телефона содержит недопустимые символы'; en = 'Phone number contains invalid characters'; pl = 'Numer telefonu zawiera nieprawidłowe znaki.';es_ES = 'Número de teléfonos contiene símbolos inadmisibles';es_CO = 'Número de teléfonos contiene símbolos inadmisibles';tr = 'Telefon numarası uygunsuz karakterleri içeriyor';it = 'Il numero di telefono contiene caratteri invalidi';de = 'Die Telefonnummer enthält ungültige Zeichen'"));
	EndIf;
	
	If CountryCode = "7" OR CountryCode = "+7" Then
		If StrLen(NumbersOnly(PhoneNumber)) > 7 Then
			ErrorsList.Add("PhoneNumber", NStr("ru = 'В России номер телефона не может быть больше 7 цифр'; en = 'Russian phone numbers cannot contain more than 7 digits'; pl = 'W Rosji numer telefonu nie może przekraczać 7 cyfr';es_ES = 'En Rusia el número de teléfono no puede superar 7 dígitos';es_CO = 'En Rusia el número de teléfono no puede superar 7 dígitos';tr = 'Rusya''da telefon numarası 7 haneden fazla olamaz';it = 'I numeri di telefoni russi non possono avere più di 7 cifre';de = 'In Russland darf die Telefonnummer nicht mehr als 7-stellig sein'"));
		EndIf;
	EndIf;
	
	If StrStartsWith(CityCode, "9") AND StrLen(CityCode) <> 3 Then
		ErrorsList.Add("PhoneNumber", NStr("ru = 'В России номера мобильных телефонов должны содержать 3 цифры'; en = 'Russian cell phone numbers must contain 3 digits'; pl = 'W Rosji numery telefonów komórkowych muszą zawierać 3 cyfry';es_ES = 'En Rusia los números de teléfonos móviles deben contener 3 dígitos';es_CO = 'En Rusia los números de teléfonos móviles deben contener 3 dígitos';tr = 'Rusya''da cep telefon numaraları 3 rakam içermelidir';it = 'I numeri di telefono di cellulare russi devono contenere 3 cifre';de = 'In Russland müssen die Mobiltelefonnummern 3-stellig sein'"));
	EndIf;
	
	Return ErrorsList;
EndFunction

// Notifies of any filling errors based on PhoneFillErrorsServer function results.
&AtClient
Procedure NotifyFillErrors(ErrorsList)
	
	If ErrorsList.Count()=0 Then
		ShowMessageBox(, NStr("ru='Телефон введен корректно.'; en = 'Valid phone number entered.'; pl = 'Podano prawidłowy numer telefonu.';es_ES = 'Número de teléfono válido introducido.';es_CO = 'Número de teléfono válido introducido.';tr = 'Geçerli telefon numarası girildi.';it = 'Numero di telefono valido immesso.';de = 'Gültige Telefonnummer eingegeben.'"));
		Return;
	EndIf;
	
	ClearMessages();
	
	// Value - XPath, presentatin - error details.
	For Each Item In ErrorsList Do
		CommonClientServer.MessageToUser(Item.Presentation,,,
		PathToFormDataByXPath(Item.Value));
	EndDo;
	
EndProcedure    

&AtClient 
Function PathToFormDataByXPath(XPath) 
	Return XPath;
EndFunction

&AtServer
Procedure ClearPhoneServer()
	CountryCode     = "";
	CityCode     = "";
	PhoneNumber = "";
	Extension    = "";
	Comment   = "";
	Presentation = "";
	
	Modified = True;
EndProcedure

// Checks whether the string contains only ~
//
// Parameters:
//  CheckString          - String - a string to check.
//
// Returns:
//   Boolean - True - the string contains only numbers or is empty, False - the string contains other characters.
//
&AtClient
Function PhoneNumberContainsProhibitedChars(Val CheckString)
	
	AllowedCharacterList = "+-.,() wp1234567890";
	Return StrSplit(CheckString, AllowedCharacterList, False).Count() > 0;
	
EndFunction

&AtClient
Function NumbersOnly(Val Row)
	
	ExcessCharacters = StrConcat(StrSplit(Row, "0123456789"), "");
	Result     = StrConcat(StrSplit(Row, ExcessCharacters), "");
	
	Return Result;
	
EndFunction

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


#EndRegion
