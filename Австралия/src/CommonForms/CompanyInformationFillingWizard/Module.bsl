
#Region Variables

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

#EndRegion

#Region FormEventHandlers

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber		= 1;
	mFirstPage				= 1;
	mLastPage				= 7;
	mFormRecordCompleted	= False;
	
	If ValueIsFilled(CompanyNewRef) Then
		CompanyRef = CompanyNewRef;
	EndIf;
	
	SetActivePage();
	SetButtonsEnabled();
	
	FormManagment();
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers, "Company");
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	UseSeveralCompaniesValue = Constants.UseSeveralCompanies.Get();
	UseMultipleVATNumbersValue = Constants.UseMultipleVATNumbers.Get();
	UseSeveralCompanies = DriveClientServer.BooleanToYesNo(UseSeveralCompaniesValue);
	CompaniesCount = Catalogs.Companies.CompaniesCount();
	
	FillCompanyDetails();
	SetAppearanceOfVATNumbers();
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnCreateAtServer(ThisObject, Company, "ContactInformationGroup", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		If Exit Then
			WarningText = NStr("en = 'Data will be lost'; ru = 'Данные будут потеряны';pl = 'Dane zostaną utracone';es_ES = 'Datos se perderán';es_CO = 'Datos se perderán';tr = 'Veriler kaybolacak';it = 'I dati andranno persi';de = 'Daten gehen verloren'"); 			
			Return;			
		EndIf;
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		QueryText = NStr("en = 'Do you want to save the changes?'; ru = 'Сохранить изменения?';pl = 'Czy chcesz zapisać zmiany?';es_ES = '¿Quiere guardar los cambios?';es_CO = '¿Quiere guardar los cambios?';tr = 'Değişikleri kaydetmek istiyor musunuz?';it = 'Volete salvare le modifiche?';de = 'Möchten Sie die Änderungen speichern?'");
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel, True, True);
		
		If Not Cancel Then
			WriteFormChanges();
			Modified = False;
			Close();
		EndIf;
		
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AccountingPolicy" Then
		Modified = True;
		If DriveClientServer.YesNoToBoolean(IsNewCompany) Then
			AccountingPolicyIsSet = True;
			If Parameter <> Undefined Then
				GetAccountingPolicyFromTempStorage(Parameter);
			EndIf;
		Else
			AccountingPolicyIsSet = AccountingPolicyIsSet(CompanyRef);
		EndIf;
		FormManagment();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure CompanyPricesPrecisionOnChange(Item)
	
	If ValueIsFilled(CompanyRef) Then
		
		If PricesPrecision > Company.PricesPrecision Then
			
			ShowMessageBox(Undefined, NStr("en = 'Price precision cannot be less than current value.'; ru = 'Точность цены не может быть меньше указанного значения.';pl = 'Dokładność cen nie może być mniejsza niż bieżąca wartość.';es_ES = 'La precisión del precio no puede ser inferior al valor actual.';es_CO = 'La precisión del precio no puede ser inferior al valor actual.';tr = 'Fiyat basamağı mevcut değerden daha az olamaz.';it = 'La precisione del prezzo non può essere inferiore al valore attuale.';de = 'Genauigkeit von Preisen kann nicht unter dem aktuellen Wert liegen.'"));
			Company.PricesPrecision = PricesPrecision;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure

// Procedure - CompleteFilling command handler.
//
&AtClient
Procedure CompleteFilling(Command)
	
	WriteFormChanges();
	Close(True);
	
EndProcedure

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	IsLastPage = (mCurrentPageNumber = mLastPage);
	ExecuteActionsOnTransitionToNextPage(Cancel, , IsLastPage);
	If Cancel Then
		Return;
	EndIf;
	
	If IsLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel, False);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
Procedure Decoration44Click(Item)
	
	PageClick(1);
	
EndProcedure

&AtClient
Procedure Decoration32Click(Item)
	
	PageClick(2);
	
EndProcedure

&AtClient
Procedure Decoration34Click(Item)
	
	PageClick(3);
	
EndProcedure

&AtClient
Procedure Decoration36Click(Item)
	
	PageClick(4);
	
EndProcedure

&AtClient
Procedure Decoration48Click(Item)
	
	PageClick(5);
	
EndProcedure

&AtClient
Procedure Decoration38Click(Item)
	
	PageClick(6);
	
EndProcedure

&AtClient
Procedure ChiefExecutiveNameOnChange(Item)
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.Ref) Then
		Return;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = Cashier.Ref Then
		Cashier.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChiefAccountantNameOnChange(Item)
	
	If Not ValueIsFilled(ChiefAccountant.Ref) Then
		Return;
	EndIf;
	
	If ChiefAccountant.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = Cashier.Ref Then
		Cashier.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = ChiefAccountant.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure CashierDescriptionOnChange(Item)
	
	If Not ValueIsFilled(Cashier.Ref) Then
		Return;
	EndIf;
	
	If Cashier.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = Cashier.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure WarehouseSupervisorNameOnChange(Item)
	
	If Not ValueIsFilled(WarehouseSupervisor.Ref) Then
		Return;
	EndIf;
	
	If WarehouseSupervisor.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = WarehouseSupervisor.Description;
	EndIf;
	
	If WarehouseSupervisor.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = WarehouseSupervisor.Description;
	EndIf;
	
	If WarehouseSupervisor.Ref = Cashier.Ref Then
		Cashier.Description = WarehouseSupervisor.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure SpecifyAccountingPolicy(Command)
	
	SpecifyAccountingPolicyCommon();
	
EndProcedure

&AtServerNoContext
Function GetPricesRecordKey(ParametersStructure)
	
	Return InformationRegisters.AccountingPolicy.GetRecordKey(ParametersStructure);
	
EndFunction

&AtClient
Procedure UseSeveralCompaniesOnChange(Item)
	
	UseSeveralCompaniesOnChangeAtServer(UseSeveralCompanies);
	FormManagment();
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure CompanyRefOnChange(Item)
	
	FillCompanyDetails();
	FormManagment();
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers, "Company");
	
EndProcedure

&AtClient
Procedure NewCompanyOnChange(Item)
	
	FillCompanyDetails();
	FormManagment();
	
	If ValueIsFilled(CompanyNewRef) Then
		CompanyRef = CompanyNewRef;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExistingCompanyOnChange(Item)
	
	FillCompanyDetails();
	FormManagment();
	
EndProcedure

&AtClient
Procedure PrefixOnChange(Item)
	
	Company.Prefix = TrimAll(Company.Prefix);
	If StrFind(Company.Prefix, "-") > 0 Then
		
		ShowMessageBox(Undefined, NStr("en = 'The company''s prefix cannot include ""-"".'; ru = 'Префикс организации не может содержать ""-"".';pl = 'Prefiks firmy nie może zawierać ""-"".';es_ES = 'El prefijo de la empresa no puede incluir ""-"".';es_CO = 'El prefijo de la empresa no puede incluir ""-"".';tr = 'İş yeri öneki ""-"" içeremez.';it = 'Il prefisso dell''azienda non può includere ""-"".';de = 'Das Präfix der Firma darf nicht „-“ enthalten.'"));
		Company.Prefix = StrReplace(Company.Prefix, "-", "");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchTypeListOfVATNumbersOnChange(Item)
	
	If SwitchTypeListOfVATNumbers
		And Not UseMultipleVATNumbersValue Then
		
		UseMultipleVATNumbersValue = True;
		DriveServerCall.SetConstant("UseMultipleVATNumbers", UseMultipleVATNumbersValue);
		RefreshInterface();
	EndIf;
	
	VATNumbersCount = Company.VATNumbers.Count();
	
	If Not SwitchTypeListOfVATNumbers Then
		If VATNumbersCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'Cannot clear the Multiple VAT IDs check box. Several VAD IDs have already been added.'; ru = 'Не удается снять флажок Несколько номеров плательщика НДС. Уже добавлены несколько номеров плательщика НДС.';pl = 'Nie można wyczyścić pola wyboru Kilka numerów VAT. Jest już dodano kilka numerów VAT.';es_ES = 'No se puede desmarcar la casilla de verificación ""Múltiples identificadores de IVA"". Ya se han añadido varios identificadores del IVA.';es_CO = 'No se puede desmarcar la casilla de verificación ""Múltiples identificadores de IVA"". Ya se han añadido varios identificadores del IVA.';tr = 'Çoklu KDV kodları onay kutusu temizlenemiyor. Birden fazla KDV kodu zaten eklendi.';it = 'Impossibile cancellare la casella di controllo delle ID IVA multiple. Molte ID IVA sono state già aggiunte.';de = 'Das Kontrollkästchen ""Mehrere USt.-IdNrn."" kann nicht deaktiviert werden. Mehrere USt.-IdNrn. wurden bereits hinzugefügt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfVATNumbers = True;
		ElsIf VATNumbersCount = 1 Then
			Company.VATNumbers[0].RegistrationValidTill = Date(1,1,1);
		ElsIf VATNumbersCount = 0 Then
			NewLine = Company.VATNumbers.Add();
		EndIf;
	EndIf;
		
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers, "Company");
	
EndProcedure

&AtClient
Procedure VATNumberOnChange(Item)
	RefillDefaultVATNumber(Company.VATNumbers[0]);
EndProcedure
	
&AtClient
Procedure VATNumbersOnActivateRow(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		IsDefaultVATNumber = False;
		Return;
	EndIf;
	
	IsDefaultVATNumber = (CurrentData.VATNumber = Company.VATNumber);
	
EndProcedure

&AtClient
Procedure VATNumbersOnStartEdit(Item, NewRow, Clone)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		
		BlankDate = Date(1, 1, 1);
		
		CurrentRegistrationDate = BlankDate;
		CurrentValidTillDate = BlankDate;
		
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
	
	If Company.VATNumbers.Count() < 2 Then
		
		MessageText = NStr("en = 'Cannot delete the only registered VAT ID.'; ru = 'Невозможно удалить единственный зарегистрированный номер плательщика НДС.';pl = 'Nie można usunąć jedynego zarejestrowanego numeru VAT.';es_ES = 'No se puede borrar el único identificador del IVA registrado.';es_CO = 'No se puede borrar el único identificador del IVA registrado.';tr = 'Tek kayıtlı KDV kodu silinemez.';it = 'Impossibile eliminare solo l''ID IVA registrata.';de = 'Kann die einzige eingetragene USt.- IdNr. nicht löschen.'");
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
	WorkWithVATClient.SetVATNumbersRowFilter(ThisObject, "Company", CurrentData);
	
	Company.VATNumbers.Sort("RegistrationCountry, RegistrationDate, RegistrationValidTill");
	
EndProcedure

&AtClient
Procedure VATNumbersRegistrationDateOnChange(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	WorkWithVATClient.CheckValidDates(ThisObject, Item, CurrentData, "Company");
	
EndProcedure

&AtClient
Procedure VATNumbersRegistrationValidTillOnChange(Item)
	
	CurrentData = Items.VATNumbers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	WorkWithVATClient.CheckValidDates(ThisObject, Item, CurrentData, "Company");
	
EndProcedure

&AtClient
Procedure ResponsiblePersonAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		FoundChoiceData = GetResponsiblePersons(DataGetParameters);
		If FoundChoiceData.Count() > 0 Then 
			StandardProcessing = False;
			ChoiceData = FoundChoiceData;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyLegalIndividualOnChange(Item)
	FormManagment();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

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
Procedure ShowExpiredVATIDs(Command)
	
	ShowExpired = Not Items.VATNumbersShowExpiredVATIDs.Check;
	
	Items.VATNumbersShowExpiredVATIDs.Check = ShowExpired;
	Items.VATNumbersShowExpiredVATIDs.Title = ?(ShowExpired, 
		NStr("en = 'Hide expired'; ru = 'Скрыть просроченные';pl = 'Ukryj wygasłe';es_ES = 'Esconder el caducado';es_CO = 'Esconder el caducado';tr = 'Süresi bitenleri gizle';it = 'Nascondere scaduti';de = 'Abgelaufen ausblenden'"), NStr("en = 'Show expired'; ru = 'Показать просроченные';pl = 'Pokaż wygasłe';es_ES = 'Mostrar el caducado';es_CO = 'Mostrar el caducado';tr = 'Süresi bitenleri göster';it = 'Mostrare scaduti';de = 'Abgelaufen anzeigen'"));
	
	WorkWithVATClient.SetVATNumbersRowFilter(ThisObject, "Company");
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

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
	ContactsManager.UpdateContactInformation(ThisObject, Company, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

#EndRegion

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	BeginTransaction();
	
	If Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual") Then
		IndividualObject = FormAttributeToValue("Individual");
		
		MiddleName = ?(ValueIsFilled(IndividualObject.MiddleName), " " + IndividualObject.MiddleName, "");
		LastName = ?(ValueIsFilled(IndividualObject.LastName), " " + IndividualObject.LastName, "");
		IndividualObject.Description = IndividualObject.FirstName + MiddleName + LastName;
		
		IndividualObject.Write();
		Company.Individual = IndividualObject.Ref;
	EndIf;
	
	CompanyObject = FormAttributeToValue("Company");
	
	If CompanyObject.IsNew() Then
		
		CompanyObject.SetNewObjectRef(CompanyNewRef);
		
		If AccountingPolicyIsSet And AccountingPolicyRecordSet.Count() Then
			PolicyRecordSet = FormAttributeToValue("AccountingPolicyRecordSet");
			PolicyRecordSet.Write(False);
		EndIf;
		
	EndIf;
		
	If GetFunctionalOption("UseCustomizableNumbering") Then
		CompanyObject.Prefix = TrimAll(NumberingIndex);
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CompanyObject);
	// End StandardSubsystems.ContactInformation
	
	CompanyObject.Write();
	ValueToFormAttribute(CompanyObject, "Company");
	
	Numbering.WriteNumberingIndex(ThisObject, "Company");
	
	RecordSet = InformationRegisters.ResponsiblePersons.CreateRecordSet();
	RecordSet.Filter.Company.Set(CompanyObject.Ref);
	DateBegOfYear = BegOfYear(CurrentSessionDate());
	
	If ValueIsFilled(ChiefExecutiveOfficer.Description) Then
		
		ChiefExecutiveObject = FormAttributeToValue("ChiefExecutiveOfficer");
		ChiefExecutiveObject.EmploymentContractType = ?(ValueIsFilled(ChiefExecutiveObject.EmploymentContractType), ChiefExecutiveObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
		ChiefExecutiveObject.Write();
		
		CEOPosition = NStr("en = 'Chief Executive Officer'; ru = 'Генеральный директор';pl = 'Dyrektor generalny';es_ES = 'Director ejecutivo';es_CO = 'Director ejecutivo';tr = 'İcra kurulu başkanı İcra kurulu başkanı';it = 'Amministratore delegato (CEO)';de = 'Geschäftsführer'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CEOPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CEOPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.ChiefExecutiveOfficer;
		NewRow.Employee					= ChiefExecutiveObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(ChiefAccountant.Description) Then
		
		If ChiefAccountant.Description = ChiefExecutiveOfficer.Description
		 OR (ChiefAccountant.Ref <> Catalogs.Employees.EmptyRef() AND ChiefAccountant.Ref = ChiefExecutiveOfficer.Ref) Then
			ChiefAccountantObject = ChiefExecutiveObject;
		Else
			ChiefAccountantObject = FormAttributeToValue("ChiefAccountant");
			ChiefAccountantObject.EmploymentContractType = ?(ValueIsFilled(ChiefAccountantObject.EmploymentContractType), ChiefAccountantObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
			ChiefAccountantObject.Write();
		EndIf;
		
		CAPosition = NStr("en = 'Chief accountant'; ru = 'Главный бухгалтер';pl = 'Główny księgowy';es_ES = 'Jefe contable';es_CO = 'Jefe contable';tr = 'Muhasebe şefi';it = 'Direttore finanziario';de = 'Hauptbuchhalter'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CAPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CAPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.ChiefAccountant;
		NewRow.Employee					= ChiefAccountantObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(Cashier.Description) Then
		
		If Cashier.Description = ChiefExecutiveOfficer.Description
			OR (Cashier.Ref <> Catalogs.Employees.EmptyRef()
				AND Cashier.Ref = ChiefExecutiveOfficer.Ref) Then
			CashierObject = ChiefExecutiveObject;
		ElsIf Cashier.Description = ChiefAccountant.Description
			OR (Cashier.Ref <> Catalogs.Employees.EmptyRef()
				AND Cashier.Ref = ChiefAccountant.Ref) Then
			CashierObject = ChiefAccountantObject;
		Else
			CashierObject = FormAttributeToValue("Cashier");
			CashierObject.EmploymentContractType = ?(ValueIsFilled(CashierObject.EmploymentContractType), CashierObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
			CashierObject.Write();
		EndIf;
		
		CashierPosition = NStr("en = 'Cashier'; ru = 'Кассир';pl = 'Kasjer';es_ES = 'Cajero';es_CO = 'Cajero';tr = 'Kasiyer';it = 'Cassiere';de = 'Kassierer'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CashierPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CashierPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.Cashier;
		NewRow.Employee					= CashierObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(WarehouseSupervisor.Description) Then
		
		If WarehouseSupervisor.Description = ChiefExecutiveOfficer.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = ChiefExecutiveOfficer.Ref) Then
			WarehouseSupervisorObject = ChiefExecutiveObject;
		ElsIf WarehouseSupervisor.Description = ChiefAccountant.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = ChiefAccountant.Ref) Then
			WarehouseSupervisorObject = ChiefAccountantObject;
		ElsIf WarehouseSupervisor.Description = Cashier.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = Cashier.Ref) Then
			WarehouseSupervisorObject = CashierObject;
		Else
			WarehouseSupervisorObject = FormAttributeToValue("WarehouseSupervisor");
			WarehouseSupervisorObject.EmploymentContractType = ?(ValueIsFilled(WarehouseSupervisorObject.EmploymentContractType), 
																	WarehouseSupervisorObject.EmploymentContractType,
																	Enums.EmploymentContractTypes.FullTime);
			WarehouseSupervisorObject.Write();
		EndIf;
		
		WSPosition = NStr("en = 'Warehouse Supervisor'; ru = 'Кладовщик';pl = 'Kierownik magazynu';es_ES = 'Supervisor de almacén';es_CO = 'Supervisor de almacén';tr = 'Ambar denetçisi';it = 'Supervisore di magazzino';de = 'Lagerleiter'");
		
		PositionObject = Catalogs.Positions.FindByDescription(WSPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = WSPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.WarehouseSupervisor;
		NewRow.Employee					= WarehouseSupervisorObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If RecordSet.Count() > 0 Then
		RecordSet.Write(True);
	EndIf;
	
	If FinishEntering Then
		Constants.CompanyInformationIsFilled.Set(True);
	EndIf;
	
	CommitTransaction();
	
EndProcedure

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	SearchString = "Step" + String(mCurrentPageNumber);
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	If mCurrentPageNumber = 3 Then 
		StringLegalEntityIndividual = ?(Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual"), "Individual", "LegalEntity");
		Items.Step3LegalEntity.Visible	= (StringLegalEntityIndividual = "LegalEntity");
		Items.Step3Individual.Visible	= (StringLegalEntityIndividual = "Individual");
	EndIf;
		
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Company details wizard (Step %1/%2)'; ru = 'Помощник заполнения информации об организации (Шаг %1/%2)';pl = 'Kreator danych o firmie (Krok %1/%2)';es_ES = 'Asistente de detalles de la empresa (Paso %1/%2)';es_CO = 'Asistente de detalles de la empresa (Paso %1/%2)';tr = 'İş yeri bilgileri doldurma sihirbazı (Adım %1/%2)';it = 'Procedura guidata dettagli azienda (Fase %1/%2)';de = 'Assistent zum Ausfüllen von Firmeninformationen (Schritt %1/%2)'"),
		mCurrentPageNumber, mLastPage);
	
EndProcedure

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If mCurrentPageNumber = mLastPage Then
		Items.GoToNext.Title			= NStr("en = 'Finish'; ru = 'Готово';pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Terminare';de = 'Abschluss'");
		Items.GoToNext.Representation	= ButtonRepresentation.Text;
		Items.GoToNext.Font				= New Font(Items.GoToNext.Font,,, True);
	Else
		Items.GoToNext.Title			= NStr("en = 'Next'; ru = 'Далее';pl = 'Dalej';es_ES = 'Siguiente';es_CO = 'Siguiente';tr = 'İleri';it = 'Avanti';de = 'Weiter'");
		Items.GoToNext.Representation	= ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font				= New Font(Items.GoToNext.Font,,, False);
	EndIf;
	
EndProcedure

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel, FillCheck = True, Closing = False)
	
	ClearMessages();
	
	If FillCheck
		And (mCurrentPageNumber = 3
		Or Closing) Then
		
		If Not ValueIsFilled(Company.Description) Then
			
			If mCurrentPageNumber <> 3 Then 
				mCurrentPageNumber = 3;
				SetActivePage();
			EndIf;
			
			MessageText = NStr("en = 'The alias is required.'; ru = 'Требуется указать псеводним.';pl = 'Prezentacja w aplikacji jest wymagana.';es_ES = 'Se requiere un alias.';es_CO = 'Se requiere un alias.';tr = 'Unvan gerekli.';it = 'Alias richiesto.';de = 'Der Alias ist erforderlich.'");
			CommonClientServer.MessageToUser(
				MessageText,
				,
				"Company.Description",
				,
				Cancel);
		EndIf;
		
		If Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual") Then
			
			If IsBlankString(Individual.FirstName) Or IsBlankString(Individual.LastName) Then
				
				If mCurrentPageNumber <> 3 Then 
					mCurrentPageNumber = 3;
					SetActivePage();
				EndIf;
				
				If IsBlankString(Individual.FirstName) Then
					MessageText = NStr("en = 'The individual''s name is required.'; ru = 'Требуется указать имя физического лица.';pl = 'Imię i nazwisko osoby fizycznej są wymagane.';es_ES = 'Se requiere el nombre del individuo.';es_CO = 'Se requiere el nombre del individuo.';tr = 'Gerçek kişi adı gerekli.';it = 'Nome della persona fisica richiesto.';de = 'Der Name der natürlichen Person ist erforderlich.'");
					CommonClientServer.MessageToUser(
						MessageText,
						,
						"Individual.FirstName",
						,
						Cancel);
				EndIf;
				If IsBlankString(Individual.LastName) Then
					MessageText = NStr("en = 'The individual''s last name is required.'; ru = 'Требуется указать фамилию физического лица.';pl = 'Nazwisko osoby fizycznej jest wymagane.';es_ES = 'Se requiere el apellido del individuo.';es_CO = 'Se requiere el apellido del individuo.';tr = 'Kişinin soyadı gerekli.';it = 'Cognome della persona fisica richiesto.';de = 'Der Nachname der natürlichen Person ist erforderlich.'");
					CommonClientServer.MessageToUser(
						MessageText,
						,
						"Individual.LastName",
						,
						Cancel);
				EndIf;
				
			EndIf;

			
		EndIf;
		
		If Not ValueIsFilled(Company.PresentationCurrency) Then
			
			If mCurrentPageNumber <> 3 Then 
				mCurrentPageNumber = 3;
				SetActivePage();
			EndIf;
			
			MessageText = NStr("en = 'The presentation currency is required.'; ru = 'Требуется указать валюту представления отчетности.';pl = 'Waluta prezentacji jest wymagana.';es_ES = 'Se requiere la moneda de presentación.';es_CO = 'Se requiere la moneda de presentación.';tr = 'Finansal tablo para birimi gerekli.';it = 'Valuta di presentazione richiesta.';de = 'Die Währung der Berichtserstattung ist erforderlich.'");
			CommonClientServer.MessageToUser(MessageText,
				,
				"Company.PresentationCurrency",
				,
				Cancel);
		EndIf;
			
		If Not ValueIsFilled(Company.ExchangeRateMethod) Then
			
			If mCurrentPageNumber <> 3 Then 
				mCurrentPageNumber = 3;
				SetActivePage();
			EndIf;
			
			MessageText = NStr("en = 'The exchange rate method is required.'; ru = 'Требуется указать метод расчета курсов валют.';pl = 'Metoda przeliczenia kursów walut jest wymagana.';es_ES = 'Se requiere el método del tipo de cambio.';es_CO = 'Se requiere el método del tipo de cambio.';tr = 'Döviz kuru yöntemi gerekli.';it = 'Metodo del tasso di cambio richiesto.';de = 'Die Wechselkurs-Methode ist erforderlich.'");
			CommonClientServer.MessageToUser(
				MessageText,
				,
				"Company.ExchangeRateMethod",
				,
				Cancel);
		EndIf;
		
		FillCheckContactInformation(Cancel);
		
	ElsIf mCurrentPageNumber = 5
		And FillCheck Then
		
		If Not AccountingPolicyIsSet
			And Not UserWasAskedAboutPolicy Then
			
			Cancel = True;
			UserWasAskedAboutPolicy = True;
			ShowQueryBox(
				New NotifyDescription("AccountingPolicyQueryBoxHandler", ThisObject),
				NStr("en = 'The accounting policy is required for posting the company documents. Do you want to specify it now?'; ru = 'Для проведения документов организации требуется учетная политика. Выполнить настройку учетной политики сейчас?';pl = 'Polityka rachunkowości jest wymagana do zatwierdzenia dokumentów firmy. Czy chcesz określić ją teraz?';es_ES = 'La política de contabilidad es necesaria para enviar los documentos de la empresa. ¿Quiere especificarla ahora?';es_CO = 'La política de contabilidad es necesaria para enviar los documentos de la empresa. ¿Quiere especificarla ahora?';tr = 'İş yeri belgelerinin kaydedilmesi için muhasebe politikası gerekli. Şimdi belirtmek ister misiniz?';it = 'Politica contabile richiesta per la pubblicazione dei documenti aziendali. Specificarla adesso?';de = 'Die Bilanzierungsrichtlinien sind für Buchung der Firmendokumenten erforderlich. Möchten Sie diese jetzt angeben?'"),
				QuestionDialogMode.YesNo);
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure PageClick(PageNumber)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel, PageNumber > mCurrentPageNumber);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = PageNumber;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

&AtServer
Procedure FillCompanyDetails()

	If Not ValueIsFilled(IsNewCompany) Then
		
		UserSetting = SystemSettingsStorage.Load("CommonForm.CompanyInformationFillingWizard/CurrentData");
		If UserSetting = Undefined Then
			IsNewCompany = Enums.YesNo.No;
		Else
			IsNewCompany	= UserSetting.Get("IsNewCompany");
			CompanyRef		= UserSetting.Get("CompanyRef");
		EndIf;
		
	EndIf;
	
	If DriveClientServer.YesNoToBoolean(IsNewCompany) Then
		
		CompanyNewRef = Catalogs.Companies.GetRef(New UUID());
		CompanyRef = CompanyNewRef;
		
		CompanyObject = Catalogs.Companies.CreateItem();
		CompanyObject.Fill(Undefined);
		
		ValueToFormAttribute(CompanyObject,						"Company");
		ValueToFormAttribute(Catalogs.Employees.CreateItem(),	"ChiefExecutiveOfficer");
		ValueToFormAttribute(Catalogs.Employees.CreateItem(),	"ChiefAccountant");
		ValueToFormAttribute(Catalogs.Employees.CreateItem(),	"Cashier");
		ValueToFormAttribute(Catalogs.Employees.CreateItem(),	"WarehouseSupervisor");
		
		ValueToFormAttribute(Catalogs.Individuals.CreateItem(), "Individual");
		Individual.Gender = Enums.Gender.Male;
		
		Company.VATNumbers.Add();
		
		AccountingPolicyIsSet = False;
		AccountingPolicyRecordSet.Clear();
		
	Else
		
		CompanyNewRef = Catalogs.Companies.EmptyRef();
		
		If Not ValueIsFilled(CompanyRef)
			Or CompanyRef.GetObject() = Undefined Then
			CompanyRef = Catalogs.Companies.MainCompany;
		EndIf;
		
		ValueToFormAttribute(CompanyRef.GetObject(), "Company");
		PricesPrecision = CompanyRef.PricesPrecision;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	ResponsiblePersonsSliceLast.Employee,
		|	ResponsiblePersonsSliceLast.ResponsiblePersonType,
		|	ResponsiblePersonsSliceLast.Company
		|FROM
		|	InformationRegister.ResponsiblePersons.SliceLast AS ResponsiblePersonsSliceLast
		|WHERE
		|	ResponsiblePersonsSliceLast.Company = &Company";
		Query.SetParameter("Company", CompanyRef);
		
		ResponsiblePersonsTable = Query.Execute().Unload();
		
		For Each Enum In Enums.ResponsiblePersonTypes Do
			
			TableRow = ResponsiblePersonsTable.Find(Enum, "ResponsiblePersonType");
			If TableRow = Undefined Then
				ValueToFormAttribute(Catalogs.Employees.CreateItem(), XMLString(Enum));
			Else
				ValueToFormAttribute(TableRow.Employee.GetObject(), XMLString(Enum));
			EndIf;
			
		EndDo;
		
		If ValueIsFilled(CompanyRef.Individual) Then
			ValueToFormAttribute(CompanyRef.Individual.GetObject(), "Individual");
		Else
			ValueToFormAttribute(Catalogs.Individuals.CreateItem(), "Individual");
		EndIf;
		
		AccountingPolicyIsSet = AccountingPolicyIsSet(CompanyRef);
		
	EndIf;
	
	If Company.Description = NStr("en = 'LLC ""Our company""'; ru = 'ООО ""Наша фирма""';pl = 'Sp. z o. o. ""Nasza firma""';es_ES = 'LLC ""Nuestra empresa""';es_CO = 'LLC ""Nuestra empresa""';tr = '""İş yerimiz"" Ltd.';it = 'LLC ""La nostra azienda""';de = '""Unsere Firma"" GmbH'") Then
		Company.Description = "";
	EndIf;
	
	If Not ValueIsFilled(Company.LegalEntityIndividual) Then
		Company.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;	
	EndIf;
	
	If GetFunctionalOption("UseCustomizableNumbering") Then
		Numbering.ShowNumberingIndex(ThisObject, CompanyRef);
		Items.Prefix.Visible = False;
		Items.Prefix1.Visible = False;
	Else
		PrefixOnOpen = Company.Prefix;
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, Company);
	// End StandardSubsystems.ContactInformation
	
	If Not ValueIsFilled(ChiefAccountant.OverrunGLAccount) Then
		ChiefAccountant.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.SettlementsHumanResourcesGLAccount) Then
		ChiefAccountant.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.AdvanceHoldersGLAccount) Then
		ChiefAccountant.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.OverrunGLAccount) Then
		ChiefExecutiveOfficer.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.SettlementsHumanResourcesGLAccount) Then
		ChiefExecutiveOfficer.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.AdvanceHoldersGLAccount) Then
		ChiefExecutiveOfficer.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(Cashier.OverrunGLAccount) Then
		Cashier.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(Cashier.SettlementsHumanResourcesGLAccount) Then
		Cashier.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(Cashier.AdvanceHoldersGLAccount) Then
		Cashier.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.OverrunGLAccount) Then
		WarehouseSupervisor.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.SettlementsHumanResourcesGLAccount) Then
		WarehouseSupervisor.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.AdvanceHoldersGLAccount) Then
		WarehouseSupervisor.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
		
	SwitchTypeListOfVATNumbers = (Company.VATNumbers.Count() > 1);
	
EndProcedure

&AtServerNoContext
Function AccountingPolicyIsSet(CompanyRef)
	
	Return InformationRegisters.AccountingPolicy.AccountingPolicyIsSet(CurrentSessionDate(), CompanyRef);
	
EndFunction

&AtClient
Procedure FormManagment()

	Items.GroupUseSeveralCompanies.Visible	= Not CompaniesCount;
	Items.GroupSeveralCompanies.Visible		= UseSeveralCompaniesValue;
	Items.CompanyRef.Visible				= Not DriveClientServer.YesNoToBoolean(IsNewCompany);
	Items.Decoration2.Visible				= Not AccountingPolicyIsSet;
	
	Items.CompanyLegalForm.Visible = (Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.LegalEntity"));
	
	WorkWithVATClient.SetVisibleOfVATNumbers(ThisObject, SwitchTypeListOfVATNumbers, "Company");
	
	If AccountingPolicyIsSet Then
		Items.EnterAccountingPolicy.Title = NStr("en = 'The accounting policy'; ru = 'Учетная политика';pl = 'Polityka rachunkowości';es_ES = 'La política de contabilidad';es_CO = 'La política de contabilidad';tr = 'Muhasebe politikası';it = 'Politica contabile';de = 'Die Bilanzierungsrichtlinien'");
	Else
		Items.EnterAccountingPolicy.Title = NStr("en = 'the accounting policy'; ru = 'учетная политика';pl = 'polityka rachunkowości';es_ES = 'la política de contabilidad';es_CO = 'la política de contabilidad';tr = 'muhasebe politikası';it = 'politica contabile';de = 'die Bilanzierungsrichtlinien'");
	EndIf;
	
	PrecisionAppearanceClient.FillPricesPrecisionChoiceList(CompanyRef, Items.CompanyPricesPrecision.ChoiceList);
	
EndProcedure

&AtServer
Procedure UseSeveralCompaniesOnChangeAtServer(UseSeveralCompanies)
		
	UseSeveralCompaniesValue = DriveClientServer.YesNoToBoolean(UseSeveralCompanies);
	Constants.UseSeveralCompanies.Set(UseSeveralCompaniesValue);
	
EndProcedure

&AtClient
Procedure RefillDefaultVATNumber(CurrentData)
	
	MessageText = "";
	
	If WorkWithVATClient.CheckSelectedVATNumber(CurrentData, MessageText) Then
		
		Company.VATNumber = CurrentData.VATNumber;
		SetAppearanceOfVATNumbers();
		ThisObject.Modified = True;
		
	Else
		
		CurrentData.VATNumber = Company.VATNumber;
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
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
	
	FilterItem.LeftValue = New DataCompositionField("Company.VATNumbers.VATNumber");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Company.VATNumber;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "PresetDefault";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Default VAT ID'; ru = 'Номер плательщика НДС по умолчанию';pl = 'Domyślny numer VAT';es_ES = 'Identificador del IVA por defecto';es_CO = 'Identificador del IVA por defecto';tr = 'Varsayılan KDV kodu';it = 'ID IVA predefinita';de = 'Standard-USt.-IdNr.'");
		
	// Conditional appearance for expired VAT IDs
	ConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
	
	Field = ConditionalAppearanceItem.Fields.Items.Add();
	Field.Field = New DataCompositionField("VATNumbers");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Company.VATNumbers.Expired");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "PresetExpired";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Expired VAT IDs'; ru = 'Просроченные номера плательщика НДС';pl = 'Wygasłe numery VAT';es_ES = 'Identificador del IVA caducado';es_CO = 'IVA caducado';tr = 'Süresi bitmiş KDV kodları';it = 'ID IVA scadute';de = 'Abgelaufene USt.- IdNrn.'");
	
EndProcedure

&AtClient
Procedure AccountingPolicyQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		SpecifyAccountingPolicyCommon();
	EndIf;

EndProcedure

&AtClient
Procedure SpecifyAccountingPolicyCommon()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Period", CommonClient.SessionDate());
	ParametersStructure.Insert("Company", CompanyRef);
	
	If ValueIsFilled(Company.Description) Then
		ParametersStructure.Insert("CompanyDescription", Company.Description);
	EndIf;
	
	VATNumberIsFilled = ?(Company.VATNumbers.Count() > 0, ValueIsFilled(Company.VATNumbers[0].VATNumber), False);
	ParametersStructure.Insert("VATNumberIsFilled", VATNumberIsFilled);
	
	If Not DriveClientServer.YesNoToBoolean(IsNewCompany) Then
		
		RecordKey = GetPricesRecordKey(ParametersStructure);
		If RecordKey.RecordExists Then
			
			RecordKey.Delete("RecordExists");
			ParametersStructure.Period = RecordKey.Period;
			
			ParametersArray = New Array;
			ParametersArray.Add(RecordKey);
			RecordKeyRegister = New("InformationRegisterRecordKey.AccountingPolicy", ParametersArray);
			ParametersStructure.Insert("Key", RecordKeyRegister);
			
			OpenForm("InformationRegister.AccountingPolicy.RecordForm", ParametersStructure);
			
		Else
			
			OpenForm("InformationRegister.AccountingPolicy.RecordForm", ParametersStructure);
			
		EndIf;
		
	Else
		
		ParametersStructure.Period = CommonClient.SessionDate();
		
		ParametersStructure.Insert("RecordSetTempStorageAddress", PutAccountingPolicyToTempStorage());
		
		OpenForm("InformationRegister.AccountingPolicy.RecordForm", ParametersStructure, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Function PutAccountingPolicyToTempStorage()
	
	Return PutToTempStorage(AccountingPolicyRecordSet.Unload(), UUID);
	
EndFunction

&AtServer
Procedure GetAccountingPolicyFromTempStorage(Address)
	
	AccountingPolicyRecordSet.Load(GetFromTempStorage(Address));
	
EndProcedure

&AtServerNoContext
Function GetResponsiblePersons(DataGetParameters)
	
	Return Catalogs.Employees.GetChoiceData(DataGetParameters);
	
EndFunction

&AtServer
Procedure FillCheckContactInformation(Cancel)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Company, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

#EndRegion

