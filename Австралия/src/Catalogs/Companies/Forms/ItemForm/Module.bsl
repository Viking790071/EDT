#Region Variables

&AtClient
Var DoFormClosingChecks;

#EndRegion

#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	UseSeveralCompanies = GetFunctionalOption("UseSeveralCompanies");
	If Not ValueIsFilled(Object.Ref) AND Not UseSeveralCompanies Then
		ErrorText = NStr("en = 'Please, enable ""Settings>Company>Use multiple businesses accoutning"" before you can create a new company.'; ru = 'Перед созданием новой организации включите настройку в меню Настройки>Организация>Использовать учет по нескольким организациям.';pl = 'Proszę, włącz ""Ustawienia>Firma>Używaj kilku rachunkowości biznesowych"" zanim będziesz mieć możliwość utworzenia nowej firmy.';es_ES = 'Por favor, habilite ""Configuración>Empresa>Usar la contabilidad de múltiples empresas"" antes de crear una nueva empresa.';es_CO = 'Por favor, habilite ""Configuración>Empresa>Usar la contabilidad de múltiples empresas"" antes de crear una nueva empresa.';tr = 'Yeni iş yeri yaratmak için lütfen ""Ayarlar>İş yeri>Bir kaç iş yeri muhasebe"" ayarlarını etkinleştirin.';it = 'Per piacere abilitare ""Impostazioni>Azienda>Usa contabilità per più aziende"" prima di poter creare un''altra azienda.';de = 'Bitte aktivieren Sie ""Einstellungen>Firma>Mehrere Geschäftsbuchhaltungen verwenden"" erst, bevor Sie eine neue Firma erstellen können.'");
		Raise ErrorText;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		
		GenerateDescriptionAutomatically = True;
		
		If ValueIsFilled(Object.Individual) Then
			ReadIndividual(Object.Individual);
		EndIf;
		
		If Object.VATNumbers.Count() = 0 Then
			Object.VATNumbers.Add();
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Object.Individual) Then
		Items.Surname.AutoChoiceIncomplete		= Undefined;
		Items.FirstName.AutoChoiceIncomplete	= Undefined;
		Items.MiddleName.AutoChoiceIncomplete	= Undefined;
	EndIf;
	
	IsWebClient = CommonClientServer.IsWebClient();
	Items.CommandBarLogo.Visible		= IsWebClient;
	Items.CommandBarFacsimile.Visible	= IsWebClient;
	
	Numbering.ShowNumberingIndex(ThisObject);
	Items.Prefix.Visible = Not GetFunctionalOption("UseCustomizableNumbering");
	PrefixOnOpen = Object.Prefix;
	PresentationCurrency = Object.PresentationCurrency;
	PricesPrecision = Object.PricesPrecision;
	
	FormManagement(ThisObject);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	AdditionalParameters.Insert("DeferredInitialization", True);
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnCreateAtServer(ThisObject, Object, "ContactInformationGroup", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation

	SetSwitchTypeListOfVATNumbers();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "DataProcessor.FilesOperations.Form.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		If WorkWithLogo Then
			
			Object.LogoFile = ValueSelected;
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ValueSelected;
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainAccount" AND Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "Write_File" Then
		
		If WorkWithLogo Then
			
			Modified	= True;
			Object.LogoFile = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			WorkWithLogo = False;
			
		ElsIf WorkWithFacsimile Then
			
			Modified	= True;
			Object.FileFacsimilePrinting = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			WorkWithFacsimile = False;
			
		EndIf;
		
	ElsIf EventName = "Write_Individuals" AND Source <> Object.Ref AND Parameter = Object.Individual Then
		
		ReadIndividual(Parameter);
		
	ElsIf EventName = "Record_ConstantsSet" Then
		
		If Source = "UseMultipleVATNumbers" Then
			WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers, "Object", Parameter.Value);
		ElsIf Source = "UseCustomizableNumbering" Then
			Items.Prefix.Visible = Not Parameter.Value;
		EndIf;
			
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
	 UpdateAdditionalAttributeItems();
	 PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.LogoFile) Then
		BinaryPictureData = DriveServer.ReferenceToBinaryFileData(CurrentObject.LogoFile, UUID);
		If BinaryPictureData <> Undefined Then
			AddressLogo = BinaryPictureData;
		EndIf;
	EndIf;
	
	If ValueIsFilled(CurrentObject.FileFacsimilePrinting) Then
		BinaryPictureData = DriveServer.ReferenceToBinaryFileData(CurrentObject.FileFacsimilePrinting, UUID);
		If BinaryPictureData <> Undefined Then
			AddressFaxPrinting = BinaryPictureData;
		EndIf;
	EndIf;
	
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		ReadIndividual(CurrentObject.Individual);
	EndIf;
	
	GenerateDescriptionAutomatically	= IsBlankString(Object.Description);
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers);
	
	PrecisionAppearanceClient.FillPricesPrecisionChoiceList(Object.Ref, Items.PricesPrecision.ChoiceList);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Save previous values for further analysis
	CurrentObject.AdditionalProperties.Insert("PreviousCompanyKind", Common.ObjectAttributeValue(CurrentObject.Ref, "LegalEntityIndividual"));
	CurrentObject.AdditionalProperties.Insert("IsNew", CurrentObject.IsNew());
	
	// An individual will be created in OnWrite()
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyType.Individual AND Not ValueIsFilled(CurrentObject.Individual) Then
		CurrentObject.Individual = Catalogs.Individuals.GetRef();
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	If GetFunctionalOption("UseCustomizableNumbering") Then
		CurrentObject.Prefix = TrimAll(NumberingIndex);
	EndIf;
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteIndividual(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadIndividual(CurrentObject.Individual);
	
	FormManagement(ThisObject);
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	SetAppearanceOfVATNumbers();
	
	Numbering.WriteNumberingIndex(ThisObject);
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
		
	Notify("Write_Companies", Object.Ref, Object.Ref);
	
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual") Then
		Notify("Write_Individuals", Object.Individual, Object.Ref);
	EndIf;
	
	WorkWithVATClient.SetVATNumbersRowFilter(ThisObject);
	
	If Not AccountingPolicyIsSet(Object.Ref) Then
		
		ShowQueryBox(
			New NotifyDescription("AccountingPolicyQueryBoxHandler", ThisObject),
			NStr("en = 'The accounting policy is required for posting the company documents. Do you want to specify it now?'; ru = 'Для проведения документов организации необходимо указать учетную политику. Выполнить настройку учетной политики сейчас?';pl = 'Polityka rachunkowości jest wymagana do zatwierdzenia dokumentów firmy. Czy chcesz określić ją teraz?';es_ES = 'La política de contabilidad es necesaria para enviar los documentos de la empresa. ¿Quiere especificarla ahora?';es_CO = 'La política de contabilidad es necesaria para enviar los documentos de la empresa. ¿Quiere especificarla ahora?';tr = 'İş yeri belgelerinin kaydedilmesi için muhasebe politikası gerekli. Şimdi belirtmek ister misiniz?';it = 'La politica contabile è richiesta per pubblicare i documenti aziendali. Specificarla adesso?';de = 'Die Bilanzierungsrichtlinien sind für Buchung der Firmendokumenten erforderlich. Möchten Sie diese jetzt angeben?'"),
			QuestionDialogMode.YesNo);
		
	EndIf;
	
	PresentationCurrency = Object.PresentationCurrency;
	
EndProcedure

&AtClient
Procedure AccountingPolicyQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		SpecifyAccountingPolicy();
	EndIf;

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		If IsBlankString(IndividualFullName.Name) Then
			MessageText = NStr("en = 'First name is not filled'; ru = 'Не заполнено имя';pl = 'Nie wypełniono imienia';es_ES = 'El nombre no está rellenado';es_CO = 'El nombre no está rellenado';tr = 'İlk ad doldurulmadı';it = 'Nome non compilato';de = 'Vorname ist nicht ausgefüllt'");
			CommonClientServer.MessageToUser(MessageText, , "Name", "IndividualFullName", Cancel);
		EndIf;
		If IsBlankString(IndividualFullName.Surname) Then
			MessageText = NStr("en = 'Last name is not filled'; ru = 'Не заполнена фамилия';pl = 'Nie wypełniono nazwiska';es_ES = 'El apellido no está rellenado';es_CO = 'El apellido no está rellenado';tr = 'Soyad doldurulmadı';it = 'Cognome non compilato';de = 'Nachname ist nicht ausgefüllt'");
			CommonClientServer.MessageToUser(MessageText, , "Surname", "IndividualFullName", Cancel);
		EndIf;
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation

	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
	If Not DoFormClosingChecks Or Exit Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure PrefixOnChange(Item)
	
	CheckPrefixNumberingIndex(Object.Prefix);
	NumberingIndex = Object.Prefix;
	
EndProcedure

&AtClient
Procedure NumberingIndexOnChange(Item)
	
	CheckPrefixNumberingIndex(NumberingIndex);
	Object.Prefix = NumberingIndex;
	
EndProcedure

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	If GenerateDescriptionAutomatically Then
		Object.Description	= Object.DescriptionFull;
	EndIf;

EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure IndividualFullNameOnChange(Item)
	
	If Not LockIndividualOnEdit() Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure AddressLogoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(True, False);
	AddImageAtClient();
	
EndProcedure

&AtClient
Procedure AddressFaxPrintingClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(False, True);
	AddImageAtClient();
	
EndProcedure

&AtClient
Procedure GroupPagesOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If ThisObject.PropertiesParameters.Property(CurrentPage.Name)
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesRunDeferredInitialization();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure SwitchTypeListOfVATNumbersOnChange(Item)
	
	VATNumbersCount = Object.VATNumbers.Count();
	
	If Not SwitchTypeListOfVATNumbers Then
		If VATNumbersCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'Cannot clear the Multiple VAT IDs check box. Several VAD IDs have already been added.'; ru = 'Не удается снять флажок Несколько номеров плательщика НДС. Уже добавлены несколько номеров плательщика НДС.';pl = 'Nie można wyczyścić pola wyboru Kilka numerów VAT. Jest już dodano kilka numerów VAT.';es_ES = 'No se puede desmarcar la casilla de verificación ""Múltiples identificadores de IVA"". Ya se han añadido varios identificadores del IVA.';es_CO = 'No se puede desmarcar la casilla de verificación ""Múltiples identificadores de IVA"". Ya se han añadido varios identificadores del IVA.';tr = 'Çoklu KDV kodları onay kutusu temizlenemiyor. Birden fazla KDV kodu zaten eklendi.';it = 'Impossibile deselezionare la casella di controllo delle ID IVA multiple. Molte ID IVA sono state già aggiunte.';de = 'Das Kontrollkästchen ""Mehrere USt.-IdNrn."" kann nicht deaktiviert werden. Mehrere USt.-IdNrn. wurden bereits hinzugefügt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfVATNumbers = True;
		ElsIf VATNumbersCount = 1 Then
			Object.VATNumbers[0].RegistrationValidTill = Date(1,1,1);
		ElsIf VATNumbersCount = 0 Then
			NewLine = Object.VATNumbers.Add();
		EndIf;
	EndIf;
		
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers);
	
EndProcedure

&AtClient
Procedure VATNumberOnChange(Item)
	RefillDefaultVATNumber(Object.VATNumbers[0]);	
EndProcedure

&AtClient
Procedure VATNumbersOnActivateRow(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		IsDefaultVATNumber = False;
		Return;
	EndIf;
	
	IsDefaultVATNumber = (CurrentData.VATNumber = Object.VATNumber);
	
EndProcedure

&AtClient
Procedure VATNumbersOnStartEdit(Item, NewRow, Clone)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		
		BlackDate = Date(1, 1, 1);
		
		CurrentRegistrationDate = BlackDate;
		CurrentValidTillDate = BlackDate;
		
	Else	
		
		CurrentRegistrationDate = CurrentData.RegistrationDate;
		CurrentValidTillDate = CurrentData.RegistrationValidTill;
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure VATNumbersBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsDefaultVATNumber Then
		
		MessageText = NStr("en = 'Cannot delete the default VAT ID.'; ru = 'Не удалось удалить номер плательщика НДС по умолчанию.';pl = 'Nie można usunąć domyślnego numeru VAT.';es_ES = 'No se puede borrar el identificador del IVA por defecto.';es_CO = 'No se puede borrar el identificador del IVA por defecto.';tr = 'Varsayılan KDV kodu silinemez.';it = 'Impossibile eliminare l''ID IVA predefinita.';de = 'Kann die USt.- IdNr. nicht löschen.'");
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		
		Return;
		
	EndIf;
	
	If Object.VATNumbers.Count() < 2 Then
		
		MessageText = NStr("en = 'Cannot delete the only registered VAT ID.'; ru = 'Не удалось удалить только зарегистрированный номер плательщика НДС.';pl = 'Nie można usunąć jedynego zarejestrowanego numeru VAT.';es_ES = 'No se puede borrar el único identificador del IVA registrado.';es_CO = 'No se puede borrar el único identificador del IVA registrado.';tr = 'Tek kayıtlı KDV kodu silinemez.';it = 'Impossibile eliminare solo l''ID IVA registrata.';de = 'Kann die einzige eingetragene USt.- IdNr. nicht löschen.'");
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure VATNumbersVATNumberOnChange(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If IsDefaultVATNumber Then
		RefillDefaultVATNumber(CurrentData);
	EndIf;
	
EndProcedure	

&AtClient
Procedure VATNumbersOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.VATNumbers.CurrentData;
	WorkWithVATClient.SetVATNumbersRowFilter(ThisObject, "Object", CurrentData);
	
	Object.VATNumbers.Sort("RegistrationCountry, RegistrationDate, RegistrationValidTill");
	
EndProcedure

&AtClient
Procedure VATNumbersRegistrationDateOnChange(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	WorkWithVATClient.CheckValidDates(ThisObject, Item, CurrentData);
	
EndProcedure

&AtClient
Procedure VATNumbersRegistrationValidTillOnChange(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	WorkWithVATClient.CheckValidDates(ThisObject, Item, CurrentData);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure PresentationCurrencyOnChange(Item)
	
	If Not Object.Ref.IsEmpty() Then
		
		If AvailableChangePresentationCurrency(PresentationCurrency, Object.Ref) Then
			PresentationCurrency = Object.PresentationCurrency;
		Else	
			Object.PresentationCurrency = PresentationCurrency;	
			
			MessageText = NStr("en = 'Cannot change the presenation currency. Accounting entries are already registered.'; ru = 'Не удалось изменить валюту представления отчетности. Бухгалтерские проводки уже зарегистрированы.';pl = 'Nie można zmienić waluty prezentacji. Wpisy księgowe są już zarejestrowane.';es_ES = 'No se puede cambiar la moneda de presentación. Las entradas contables ya están registradas.';es_CO = 'No se puede cambiar la moneda de presentación. Las entradas contables ya están registradas.';tr = 'Finansal tablo para birimi kaydedilemiyor. Kayıtlı muhasebe girişleri var.';it = 'Impossibile modificare la valuta di presentazione. Le voci di contabilità sono già state registrate.';de = 'Fehler beim Ändern der Währung für die Berichtserstattung. Buchhaltungseinträge sind bereits registriert.'");
			CommonClientServer.MessageToUser(MessageText,, "Object.PresentationCurrency");
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure PricesPrecisionOnChange(Item)
	
	If PricesPrecision > Object.PricesPrecision Then
		
		ShowMessageBox(Undefined, NStr("en = 'Price precision cannot be less than current value.'; ru = 'Точность цены не может быть меньше указанного значения.';pl = 'Dokładność cen nie może być mniejsza niż bieżąca wartość.';es_ES = 'La precisión del precio no puede ser inferior al valor actual.';es_CO = 'La precisión del precio no puede ser inferior al valor actual.';tr = 'Fiyat basamağı mevcut değerden daha az olamaz.';it = 'La precisione del prezzo non può essere inferiore al valore attuale.';de = 'Genauigkeit von Preisen kann nicht unter dem aktuellen Wert liegen.'"));
		Object.PricesPrecision = PricesPrecision;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PreviewPrintedFormProformaInvoice(Command)
	
	If Modified Then
		
		QuestionText = NStr("en = 'To check the preview, save the object. Do you want to save the object?'; ru = 'Для использования предварительного просмотра необходимо сохранить объект. Сохранить?';pl = 'Aby sprawdzić podgląd, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para comprobar la vista previa, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para comprobar la vista previa, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Önizlemeyi kontrol etmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per verificare l''anteprima, salvare l''oggetto. Salvare l''oggetto?';de = 'Um die Vorschau zu überprüfen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;
		
		ShowQueryBox(
			New NotifyDescription("PreviewPrintedFormProformaInvoiceEnd", ThisObject),
			QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		PreviewPrintedFormProformaInvoiceFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageLogo(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, save the object. Do you want to save the object?'; ru = 'Для выбора изображения необходимо сохранить объект. Сохранить?';pl = 'Aby wybrać obrazek, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Bir görsel seçmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per selezionare una immagine, salvare l''oggetto. Salvare l''oggetto?';de = 'Um das Bild auszuwählen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddLogoImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddLogoImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageLogo(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.LogoFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.LogoFile);
		
	Else
		
		MessageText = NStr("en = 'No image for editing'; ru = 'Отсутствует изображение для редактирования';pl = 'Brak obrazu do edytowania';es_ES = 'No hay imagen para editar';es_CO = 'No hay imagen para editar';tr = 'Düzenlenecek görüntü yok';it = 'Nessuna immagine per l''editing';de = 'Kein Bild zum Bearbeiten'");
		CommonClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearImageLogo(Command)
	
	Object.LogoFile = Undefined;
	AddressLogo = "";
	
EndProcedure

&AtClient
Procedure LogoOfAttachedFiles(Command)
	
	PicturesFlagsManagement(True, False);
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
Procedure AddImageFacsimile(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, save the object. Do you want to save the object?'; ru = 'Для выбора изображения необходимо сохранить объект. Сохранить?';pl = 'Aby wybrać obrazek, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Bir görsel seçmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per selezionare una immagine, salvare l''oggetto. Salvare l''oggetto?';de = 'Um das Bild auszuwählen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddFacsimileImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddFacsimileImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageFacsimile(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.FileFacsimilePrinting) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.FileFacsimilePrinting);
		
	Else
		
		MessageText = NStr("en = 'No image for editing'; ru = 'Отсутствует изображение для редактирования';pl = 'Brak obrazu do edytowania';es_ES = 'No hay imagen para editar';es_CO = 'No hay imagen para editar';tr = 'Düzenlenecek görüntü yok';it = 'Nessuna immagine per l''editing';de = 'Kein Bild zum Bearbeiten'");
		CommonClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearImageFacsimile(Command)
	
	Object.FileFacsimilePrinting = Undefined;
	AddressFaxPrinting = "";
	
EndProcedure

&AtClient
Procedure FacsimileOfAttachedFiles(Command)
	
	PicturesFlagsManagement(False, True);
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
Procedure SetAsDefaultVATNumber(Command)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		
		MessageText = NStr("en = 'Select the VAT ID.'; ru = 'Выберите номер плательщика НДС.';pl = 'Wybierz numer VAT.';es_ES = 'Seleccione el identificador del IVA.';es_CO = 'Seleccione el identificador del IVA.';tr = 'KDV kodunu seçin.';it = 'Selezionare l''ID IVA.';de = 'Die USt.-Nr. auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	RefillDefaultVATNumber(CurrentData);
		
EndProcedure

&AtClient
Procedure RefillDefaultVATNumber(CurrentData)
	
	MessageText = "";
	
	If WorkWithVATClient.CheckSelectedVATNumber(CurrentData, MessageText) Then
		
		Object.VATNumber = CurrentData.VATNumber;
		SetAppearanceOfVATNumbers();
		ThisObject.Modified = True;
		
	Else
		
		CurrentData.VATNumber = Object.VATNumber;
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExpiredVATIDs(Command)
	
	ShowExpired = Not Items.VATNumbersShowExpiredVATIDs.Check;
	
	Items.VATNumbersShowExpiredVATIDs.Check = ShowExpired;
	Items.VATNumbersShowExpiredVATIDs.Title = ?(ShowExpired, 
		NStr("en = 'Hide expired'; ru = 'Скрыть просроченные';pl = 'Ukryj wygasłe';es_ES = 'Esconder el caducado';es_CO = 'Esconder el caducado';tr = 'Süresi bitenleri gizle';it = 'Nascondere scaduti';de = 'Abgelaufen ausblenden'"), NStr("en = 'Show expired'; ru = 'Показать просроченные';pl = 'Pokaż wygasłe';es_ES = 'Mostrar el caducado';es_CO = 'Mostrar el caducado';tr = 'Süresi bitenleri göster';it = 'Mostra scadute';de = 'Abgelaufen anzeigen'"));
	
	WorkWithVATClient.SetVATNumbersRowFilter(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region OtherProceduresAndFunctions

&AtClient
Procedure CheckPrefixNumberingIndex(PrefixNumberingIndex)
	
	PrefixNumberingIndex = TrimAll(PrefixNumberingIndex);
	If StrFind(PrefixNumberingIndex, "-") > 0 Then
		ShowMessageBox(Undefined, NStr("en = 'The company''s prefix cannot include ""-"".'; ru = 'Префикс организации не может содержать ""-"".';pl = 'Prefiks firmy nie może zawierać ""-"".';es_ES = 'El prefijo de la empresa no puede incluir ""-"".';es_CO = 'El prefijo de la empresa no puede incluir ""-"".';tr = 'İş yeri öneki ""-"" içeremez.';it = 'Il prefisso dell''azienda non può includere ""-"".';de = 'Das Präfix der Firma darf nicht „-“ enthalten.'"));
		PrefixNumberingIndex = StrReplace(PrefixNumberingIndex, "-", "");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function AccountingPolicyIsSet(Company)
	
	Return InformationRegisters.AccountingPolicy.AccountingPolicyIsSet(CurrentSessionDate(), Company);
	
EndFunction

&AtClient
Procedure SpecifyAccountingPolicy()
	
	FormParameters = New Structure;
	FillingValuesParameter = New Structure;
	FillingValuesParameter.Insert("Company", Object.Ref);
	FormParameters.Insert("FillingValues", FillingValuesParameter);
	
	OpenForm("InformationRegister.AccountingPolicy.RecordForm", FormParameters, ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	// Set visibility of form items depending on the type of company
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.LegalEntity") Then
		
		Items.GroupFullName.Visible	= False;
		Items.LegalForm.Visible		= True;
		
	Else
		
		Items.GroupFullName.Visible	= True;
		Items.LegalForm.Visible		= False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PreviewPrintedFormProformaInvoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Write();
		If Not Modified Then
			PreviewPrintedFormProformaInvoiceFragment();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PreviewPrintedFormProformaInvoiceFragment()
	
	PrintParameters =New Structure;
	PrintParameters.Insert("FormTitle", NStr("en = 'Quotation print form'; ru = 'Печатная форма коммерческого предложения';pl = 'Formularz wydruku oferty cenowej';es_ES = 'Formulario de impresión de oferta';es_CO = 'Formulario de impresión de oferta';tr = 'Teklif yazdırma formu';it = 'Forma di stampa preventivo';de = 'Angebot Druckformular'"));
	PrintParameters.Insert("ID", Undefined);
	PrintParameters.Insert("Result", Undefined);
	PrintParameters.Insert("PrintInfo", Undefined);
	PrintParameters.Insert("AdditionalParameters", New Structure);
	
	PrintManagementClient.ExecutePrintCommand(
		"Catalog.Companies",
		"PreviewPrintedFormProformaInvoice",
		CommonClientServer.ValueInArray(Object.Ref),
		ThisObject,
		PrintParameters);
	
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfVATNumbers()
		
	SwitchTypeListOfVATNumbers = (Object.VATNumbers.Count() > 1);
	SetAppearanceOfVATNumbers();
	
EndProcedure

&AtServer
Procedure SetAppearanceOfVATNumbers()
	
	For Index = 1 - ThisObject.ConditionalAppearance.Items.Count() To 0 Do
		
		ConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items[-Index];
		
		If ConditionalAppearanceItem.UserSettingID = "PresetDefault" Then
			ThisObject.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
		EndIf;
		
		If ConditionalAppearanceItem.UserSettingID = "PresetExpired" Then
			ThisObject.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
		EndIf;
		
	EndDo;
	
	// Conditional appearance for default VAT IDs
	ConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
	
	Field = ConditionalAppearanceItem.Fields.Items.Add();
	Field.Field = New DataCompositionField("VATNumbers");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Object.VATNumbers.VATNumber");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Object.VATNumber;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "PresetDefault";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Default VAT ID'; ru = 'Номер плательщика НДС по умолчанию';pl = 'Domyślny numer VAT';es_ES = 'Identificador del IVA por defecto';es_CO = 'Identificador del IVA por defecto';tr = 'Varsayılan KDV kodu';it = 'ID IVA predefinita';de = 'Standard-USt.- IdNr.'");
		
	// Conditional appearance for expired VAT IDs
	ConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
	
	Field = ConditionalAppearanceItem.Fields.Items.Add();
	Field.Field = New DataCompositionField("VATNumbers");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Object.VATNumbers.Expired");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "PresetExpired";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Expired VAT IDs'; ru = 'Просроченные номера плательщика НДС';pl = 'Wygasłe numery VAT';es_ES = 'IVA caducado';es_CO = 'IVA caducado';tr = 'Süresi bitmiş KDV kodları';it = 'ID IVA scadute';de = 'Abgelaufene USt.- IdNrn.'");
	
EndProcedure

&AtServerNoContext
Function AvailableChangePresentationCurrency(Currency, Company)
	
	Result = True;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	AccountsPayableBalance.Company AS Company
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(, Company = &Company) AS AccountsPayableBalance
	|
	|UNION ALL
	|
	|SELECT 
	|	AccountsReceivableBalance.Company
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(, Company = &Company) AS AccountsReceivableBalance
	|
	|UNION ALL
	|
	|SELECT 
	|	IncomeAndExpensesTurnovers.Company
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(, , , Company = &Company) AS IncomeAndExpensesTurnovers
	|
	|UNION ALL
	|
	|SELECT 
	|	InventoryBalance.Company
	|FROM
	|	AccumulationRegister.Inventory.Balance(, Company = &Company) AS InventoryBalance";
	
	Query.SetParameter("Company", Company); 
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Individual

&AtServer
Procedure ReadIndividual(Individual)
	
	If Not ValueIsFilled(Individual) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ChangeHistoryOfIndividualNamesSliceLast.Period AS Period,
		|	ChangeHistoryOfIndividualNamesSliceLast.Ind AS Ind
		|FROM
		|	InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast";
	
	Query.SetParameter("Ind", Individual);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		RecordManager = InformationRegisters.ChangeHistoryOfIndividualNames.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		RecordManager.Read();
		ValueToFormAttribute(RecordManager, "IndividualFullName");
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteIndividual(CurrentObject)
	
	If Object.LegalEntityIndividual <> Enums.CounterpartyType.Individual Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(IndividualFullName.Period) Then
		IndividualFullName.Period = DriveServer.GetDefaultDate();
	EndIf;
	
	If Not ValueIsFilled(IndividualFullName.Ind) Then
		IndividualFullName.Ind = CurrentObject.Individual;
	EndIf;
	
	RecordManager = FormAttributeToValue("IndividualFullName");
	RecordManager.Write();
		
	If Object.Individual.IsEmpty() Then
		IndividualObject = Catalogs.Individuals.CreateItem();
		IndividualObject.SetNewObjectRef(CurrentObject.Individual);
	Else
		IndividualObject = Object.Individual.GetObject();
	EndIf;	
	
	IndividualObject.FirstName	= IndividualFullName.Name;
	IndividualObject.MiddleName	= IndividualFullName.Patronymic;
	IndividualObject.LastName	= IndividualFullName.Surname;
	IndividualObject.TIN		= CurrentObject.TIN;
	
	IndividualObject.Description = IndividualFullName.Name
		+ ?(IsBlankString(IndividualFullName.Patronymic), "", " " + IndividualFullName.Patronymic)
		+ ?(IsBlankString(IndividualFullName.Surname), "", " " + IndividualFullName.Surname);
	
	IndividualObject.Write();
	
EndProcedure

&AtClient
Function LockIndividualOnEdit()
	
	If Not Parameters.Key.IsEmpty() AND Not IndividualLocked Then
		If Not LockIndividualOnEditAtServer() Then
			ShowMessageBox(, NStr("en = 'You can not make changes to the personal data of an individual. Perhaps the data is edited by another user.'; ru = 'Не удается внести изменения в личные данные физического лица. Возможно данные редактируются другим пользователем.';pl = 'Nie można wprowadzać zmian do danych osobowych danej osoby. Możliwe że dane są edytowane przez innego użytkownika.';es_ES = 'Usted no puede hacer cambios de los datos personales de un particular. Probablemente los datos se hayan editado por otro usuario.';es_CO = 'Usted no puede hacer cambios de los datos personales de un particular. Probablemente los datos se hayan editado por otro usuario.';tr = 'Bireyin kişisel verilerinde değişiklik yapılamaz. Veriler başka bir kullanıcı tarafından düzenlenmiş olabilir.';it = 'Non è possibile apportare modifiche ai dati personali di un individuo. Forse i dati sono modificati da un altro utente.';de = 'Sie können die persönlichen Daten einer natürlichen Person nicht ändern. Vielleicht werden die Daten von einem anderen Benutzer bearbeitet.'"));
			ReadIndividual(Object.Individual);
			Return False;
		Else
			IndividualLocked = True;
			Return True;
		EndIf;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtServer
Function LockIndividualOnEditAtServer()
	
	Try
		LockDataForEdit(Object.Individual.Ref, Object.Individual.DataVersion, UUID);
		Return True;
	Except
		Return False;
	EndTry;
	
EndFunction

#EndRegion

#Region FacsimileAndLogo

&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction

&AtClient
Procedure PicturesFlagsManagement(ThisIsWorkingWithLogo = False, ThisIsWorkingWithFacsimile = False)
	
	WorkWithLogo		= ThisIsWorkingWithLogo;
	WorkWithFacsimile	= ThisIsWorkingWithFacsimile;
	
EndProcedure

&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	AnObjectsNameAttribute = "";
	
	If WorkWithLogo Then
		
		AnObjectsNameAttribute = "LogoFile";
		
	ElsIf WorkWithFacsimile Then
		
		AnObjectsNameAttribute = "FileFacsimilePrinting";
		
	EndIf;
	
	If Not IsBlankString(AnObjectsNameAttribute)
		AND ValueIsFilled(Object[AnObjectsNameAttribute]) Then
		
		FileData = GetFileData(Object[AnObjectsNameAttribute], UUID);
		AttachedFilesClient.OpenFile(FileData);
		
	Else
		
		MessageText = NStr("en = 'No preview image'; ru = 'Отсутствует изображение для просмотра';pl = 'Brak obrazu do podglądu';es_ES = 'No hay una imagen de vista previa';es_CO = 'No hay una imagen de vista previa';tr = 'Önizleme görüntüsü yok';it = 'Nessuna immagine di anteprima';de = 'Kein Vorschaubild'");
		CommonClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, save the object. Do you want to save the object?'; ru = 'Для выбора изображения необходимо сохранить объект. Сохранить?';pl = 'Aby wybrać obrazek, zapisz obiekt. Czy chcesz zapisać obiekt?';es_ES = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';es_CO = 'Para seleccionar una imagen, guarde el objeto. ¿Quiere guardar el objeto?';tr = 'Bir görsel seçmek için nesneyi kaydedin. Nesneyi kaydetmek istiyor musunuz?';it = 'Per selezionare una immagine, salvare l''oggetto. Salvare l''oggetto?';de = 'Um das Bild auszuwählen, speichern Sie das Objekt. Möchten Sie das Objekt speichern?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddImageAtClientFragment();
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    Write();
    
    
    AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
    
    Var FileID, AnObjectsNameAttribute, Filter;
    
    If WorkWithLogo Then
        
        AnObjectsNameAttribute = "LogoFile";
        
    ElsIf WorkWithFacsimile Then
        
        AnObjectsNameAttribute = "FileFacsimilePrinting";
        
    EndIf;
    
    If ValueIsFilled(Object[AnObjectsNameAttribute]) Then
        
        SeeAttachedFile();
        
    ElsIf ValueIsFilled(Object.Ref) Then
        
        FileID = New UUID;
        
        Filter = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'All Images %1|All files %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9'; ru = 'Все картинки %1|Все файлы %2|Формат bmp %3|Формат GIF %4|Формат JPEG %5|Формат PNG %6|Формат TIFF %7|Формат Icon  %8|Формат MetaFile %9';pl = 'Wszystkie obrazy %1| Wszystkie pliki%2| format bmp%3| format GIF %4| format JPEG%5| format PNG%6| format TIFF%7| format Icon %8| format MetaFile %9';es_ES = 'Todas imágenes %1|Todos archivos %2|formato bmp%3|formato GIF %4|formato JPEG %5|formato PNG %6|formato TIFF %7|formato icono %8|formato MetaArchivo %9';es_CO = 'Todas imágenes %1|Todos archivos %2|formato bmp%3|formato GIF %4|formato JPEG %5|formato PNG %6|formato TIFF %7|formato icono %8|formato MetaArchivo %9';tr = 'Tüm Görüntüler %1|Tüm dosyalar %2|bmp biçimi %3|GIF biçimi %4|JPEG biçimi %5|PNG biçimi %6|TIFF biçimi %7|Simge biçimi %8|MetaDosya biçimi %9';it = 'Tutte le immagini %1|Tutti i file %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9';de = 'Alle Bilder %1| Alle Dateien %2| bmp-Format %3| GIF-Format %4| JPEG-Format %5| PNG-Format %6| TIFF-Format %7| Icon-Format %8| MetaFile-Format %9'"),
			"(*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf",
			"(*.*)|*.*",
			"(*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle",
			"(*.gif*)|*.gif",
			"(*.jpeg;*.jpg)|*.jpeg;*.jpg",
			"(*.png*)|*.png",
			"(*.tif)|*.tif",
			"(*.ico)|*.ico",
			"(*.wmf;*.emf)|*.wmf;*.emf");
        
        AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
        
    EndIf;

EndProcedure

&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FileOwner", Object.Ref);
	ParametersStructure.Insert("ChoiceMode", True);
	ParametersStructure.Insert("CloseOnChoice", True);
	
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFiles", ParametersStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure AddLogoImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddLogoImageFragment();

EndProcedure

&AtClient
Procedure AddLogoImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(True, False);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure

&AtClient
Procedure AddFacsimileImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddFacsimileImageFragment();

EndProcedure

&AtClient
Procedure AddFacsimileImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(False, True);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

&AtServer
Procedure PropertiesRunDeferredInitialization()
	PropertyManager.FillAdditionalAttributesINForm(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	ContactsManagerClient.OnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	ContactsManagerClient.Clearing(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	ContactsManagerClient.ExecuteCommand(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	ContactsManagerClient.AutoComplete(Text, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	ContactsManagerClient.ChoiceProcessing(ThisObject, SelectedValue, Item.Name, StandardProcessing);
EndProcedure

&AtServer
Procedure Attachable_UpdateContactInformation(Result) Export
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

#EndRegion

#Region Initialization

DoFormClosingChecks = True;

#EndRegion

#EndRegion