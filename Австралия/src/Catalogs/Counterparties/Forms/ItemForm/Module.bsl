#Region Variables

&AtClient
Var UpdateSubordinatedInvoice;

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		OnCreateOnReadAtServer();
		FillObjectWithDefaultValues(Parameters);
	EndIf;
	
	If Object.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		Items.DescriptionFull.Title	= NStr("en = 'Name, surname'; ru = 'Фамилия, имя, отчество';pl = 'Imię, nazwisko';es_ES = 'Nombre, apellido';es_CO = 'Nombre, apellido';tr = 'İsim, soyadı';it = 'Nome, cognome';de = 'Name, Vorname'");
	Else
		Items.DescriptionFull.Title	= NStr("en = 'Legal name'; ru = 'Юридическое наименование';pl = 'Nazwa prawna';es_ES = 'Nombre legal';es_CO = 'Nombre legal';tr = 'Yasal unvan';it = 'Nome legale';de = 'Offizieller Name'");
	EndIf;
	
	UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
	UsePurchaseOrderApproval = GetFunctionalOption("UsePurchaseOrderApproval");
	
	ErrorCounterpartyHighlightColor	= StyleColors.ErrorCounterpartyHighlightColor;
	ExecuteAllChecks(ThisObject);
	
	SetFormTitle(ThisObject);
	
	SetTitleStagesOfPayment();
	
	If GetFunctionalOption("UseCustomizableNumbering") Then
		Numbering.ShowNumberingIndex(ThisObject);
	EndIf;
	
	FOUseVIESVATNumberValidation = GetFunctionalOption("UseVIESVATNumberValidation");
	FillVATValidationAttributes();
	
	SetSupplierPriceTypesChoiceParameters(Object.Ref);
	
	Items.LastEvent.Visible = GetFunctionalOption("UseDocumentEvent");
	
	PurchaseOrdersApprovalType = Constants.PurchaseOrdersApprovalType.Get();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters, False);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ContactInformation
	CIParameters = New Structure;
	CIParameters.Insert("ItemForPlacementName", "ContactInformationGroup");
	CIParameters.Insert("FormItemTitleLocation", FormItemTitleLocation.Left);
	ContactsManager.OnCreateAtServer(ThisObject, Object, CIParameters);
	CIParameters.Insert("ObjectIndex", 0);
	For Each ContactPerson In ContactPersonsData Do
		CIParameters.ItemForPlacementName = ContactPerson.ContactInformationGroup;
		CIParameters.ObjectIndex = ContactPerson.LineNumber;
		ContactsManager.OnCreateAtServer(ThisObject, ContactPerson.ContactPerson, CIParameters);
	EndDo;
	// End StandardSubsystems.ContactInformation
	
	If Common.SubsystemExists("StandardSubsystems.SMS") Then
		ModuleSMS  = Common.CommonModule("SMS");
		CanSendSMSMessage = ModuleSMS.CanSendSMSMessage();
	Else
		CanSendSMSMessage = False;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	FormManagement();
	
	SetVisiblePaymentDetails();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettlementAccountsAreChanged" Then
		
		Object.GLAccountCustomerSettlements = Parameter.GLAccountCustomerSettlements;
		Object.CustomerAdvancesGLAccount = Parameter.CustomerAdvanceGLAccount;
		Object.GLAccountVendorSettlements = Parameter.GLAccountVendorSettlements;
		Object.VendorAdvancesGLAccount = Parameter.AdvanceGLAccountToSupplier; 
		Modified = True;
		
	ElsIf EventName = "SettingMainAccount" AND Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "Write_ContactPerson" Then
		
		If Parameter.Owner = Object.Ref Then
			
			NewItemsIDs = New Array;
			ContactPersonsRows = ContactPersonsData.FindRows(New Structure("ContactPerson", Parameter.ContactPerson));
			If ContactPersonsRows.Count() = 0 Then
				ContactPersonsDataRow = ContactPersonsData.Add();
				ContactPersonsDataRow.ContactPerson = Parameter.ContactPerson;
				AfterContactPersonAddingOnClient(ContactPersonsDataRow.GetID());
				ContactPersonsDataRow = ContactPersonsData.FindByID(ContactPersonsDataRow.GetID());
				ContactPersonsRows.Add(ContactPersonsDataRow);
				NewItemsIDs.Add(ContactPersonsDataRow.LineNumber);
			EndIf;
			
			RefreshContactPersonsItems(False, NewItemsIDs);
			RefreshContactPersonsContactInformation(NewItemsIDs);
			
		ElsIf Parameter.PreviousOwner = Object.Ref Then
			
			ContactPersonsRows = ContactPersonsData.FindRows(New Structure("ContactPerson", Parameter.ContactPerson));
			If ContactPersonsRows.Count() > 0 Then
				
				IDsArray = New Array;
				For Each ContactPersonsDataRow In ContactPersonsRows Do
					IDsArray.Add(ContactPersonsDataRow.LineNumber);
				EndDo;
				DeleteContactPersons(IDsArray);
				Modified = True;
				
			EndIf;
			
		EndIf;
		
	ElsIf EventName = "VATNumberWasChecked" Then
		
		If Parameter = Object.Ref Then
			
			FillVATValidationAttributes();
			
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
	
	If UsersClientServer.IsExternalUserSession() Then
		Return;
	EndIf;
	
	OnCreateOnReadAtServer();
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	For Each ContactPerson In ContactPersonsData Do
		DeleteCommandsAndFormItems(ContactPerson.ContactInformationGroup);
		ContactsManager.OnReadAtServer(ThisObject,
			ContactPerson.ContactPerson,
			ContactPerson.ContactInformationGroup,
			ContactPerson.LineNumber);
	EndDo;
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// Duplicates blocking
	If Not WriteParameters.Property("NotToCheckDuplicates") Then
		
		DuplicateCheckingParameters = DriveClient.GetDuplicateCheckingParameters(ThisObject, "ContactInformationAdditionalAttributeDetails");
		DuplicatesTableStructure = DuplicatesTableStructureAtServer(DuplicateCheckingParameters);
		
		If ValueIsFilled(DuplicatesTableStructure.DuplicatesTableAddress) Then
			
			Cancel = True;
			
			FormParameters = New Structure;
			FormParameters.Insert("Ref", DuplicateCheckingParameters.Ref);
			FormParameters.Insert("DuplicatesTableStructure", DuplicatesTableStructure);
			
			NotificationDescriptionOnCloseDuplicateChecking = New NotifyDescription("OnCloseDuplicateChecking", ThisObject);
			
			OpenForm("DataProcessor.DuplicateChecking.Form.DuplicateChecking",
				FormParameters,
				ThisObject,
				True,
				,
				,
				NotificationDescriptionOnCloseDuplicateChecking);
				
		EndIf;
		
	EndIf;
	// End Duplicates blocking
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteTagsData(CurrentObject);
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	For Each ContactPerson In ContactPersonsData Do
		ContactsManager.BeforeWriteAtServer(ThisObject, ThisObject[ContactPerson.ContactPersonObject], , ContactPerson.ContactInformationGroup);
	EndDo;
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Duplicates blocking
	If ValueIsFilled(DuplicateRulesIndexTableAddress) And ValueIsFilled(Object.Ref) Then
		CurrentObject.AdditionalProperties.Insert("DuplicateRulesIndexTableAddress", DuplicateRulesIndexTableAddress);
	EndIf;
	
	If ValueIsFilled(ModificationTableAddress) Then
		CurrentObject.AdditionalProperties.Insert("ModificationTableAddress", ModificationTableAddress);
	EndIf;
	// End Duplicates blocking

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteContactPersonsData(CurrentObject);
	
	WriteParameters.Insert("ContactPersonsToBeNotified", CurrentObject.AdditionalProperties.ContactPersonsToBeNotified);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.ContactAfterWrite(ThisObject, Object, WriteParameters, "Counterparties");
	// End StandardSubsystems.Interactions
	
	SetFormTitle(ThisObject);
	Notify("AfterRecordingOfCounterparty", Object.Ref);
	Notify("Write_Counterparty", Object.Ref, ThisObject);
	
	For Each ContactPersonToBeNotified In WriteParameters.ContactPersonsToBeNotified Do
		Notify("Write_ContactPerson_Counterparty", ContactPersonToBeNotified, ThisObject);
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Not ValueIsFilled(CurrentObject.ContactPerson) And ContactPersonsData.Count() Then
		For Each RowCP In ContactPersonsData Do
			If ValueIsFilled(RowCP.ContactPerson) Then
				CurrentObject.ContactPerson = RowCP.ContactPerson;
				Break;
			EndIf;
		EndDo;
		If ValueIsFilled(CurrentObject.ContactPerson) Then
			CurrentObject.Write();
		EndIf;
	EndIf;
	
	ReadAdditionalInformationPanelData();
	
	WorkWithVIESServer.WriteVIESValidationResult(ThisObject, Object.Ref);
	
	SetSupplierPriceTypesChoiceParameters(Object.Ref);
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	For Each ContactPerson In ContactPersonsData Do
		ContactsManager.AfterWriteAtServer(ThisObject,
			ThisObject[ContactPerson.ContactPersonObject]);
	EndDo;
	// End StandardSubsystems.ContactInformation
	
	Numbering.WriteNumberingIndex(ThisObject);
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	For Each ContactPerson In ContactPersonsData Do
		ContactsManager.FillCheckProcessingAtServer(ThisObject,
			ThisObject[ContactPerson.ContactPersonObject],
			Cancel);
		If Cancel Then
			Break;
		EndIf;
	EndDo;
	If NOT Cancel Then
		ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	EndIf;
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	RolesAndBillingDetailsFillCheck(Cancel);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtClient
Procedure SupplierPriceTypesCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Catalog.SupplierPriceTypes.ObjectForm", 
		New Structure("Counterparty, Description", Object.Ref, Item.EditText),
		Item);

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DebtBalanceURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "BalanceContext");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Ref));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.StatementOfAccount.Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure SalesAmountURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "SalesDynamicsByCustomers");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Ref));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.NetSales.Form", FormParameters, ThisObject, UUID);

EndProcedure

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	Object.DescriptionFull = StrReplace(Object.DescriptionFull, Chars.LF, " ");
	If GenerateDescriptionAutomatically Then
		Object.Description = Object.DescriptionFull;
	EndIf;
	
EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual");
	
	Items.DateOfBirth.Visible	= IsIndividual;
	Items.Gender.Visible		= IsIndividual;
	Items.LegalForm.Visible		= Not IsIndividual;
	
	If IsIndividual Then
		Items.DescriptionFull.Title	= NStr("en = 'Name, surname'; ru = 'Фамилия, имя, отчество';pl = 'Imię, nazwisko';es_ES = 'Nombre, apellido';es_CO = 'Nombre, apellido';tr = 'İsim, soyadı';it = 'Nome, cognome';de = 'Name, Vorname'");
	Else
		Items.DescriptionFull.Title	= NStr("en = 'Legal name'; ru = 'Юридическое наименование';pl = 'Nazwa prawna';es_ES = 'Nombre legal';es_CO = 'Nombre legal';tr = 'Yasal unvan';it = 'Nome legale';de = 'Offizieller Name'");
	EndIf;
	
EndProcedure

&AtClient
Procedure TINOnChange(Item)
	
	GenerateDuplicateChecksPresentation(ThisObject);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure VATNumberOnChange(Item)
	
	If FOUseVIESVATNumberValidation Then
		CheckVATNumberAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure DataChecksPresentationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If StrFind(FormattedStringURL, "ShowDuplicates") > 0 Then
		
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("TIN",			TrimAll(Object.TIN));
		FormParameters.Insert("IsLegalEntity",	IsLegalEntity(Object.LegalEntityIndividual));
		
		OpenForm("Catalog.Counterparties.Form.DuplicatesChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	TagID = Mid(FormattedStringURL, StrLen("Tag_")+1);
	TagsRow = TagsData.FindByID(TagID);
	TagsData.Delete(TagsRow);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CustomerOnChange(Item)
	
	FormManagement();
	
	CheckBillingByContracts()
	
EndProcedure

&AtClient
Procedure DoOperationsByContractsOnChange(Item)
	
	SetVisiblePaymentDetails();
	
EndProcedure

&AtClient
Procedure SupplierOnChange(Item)
	
	CheckBillingByContracts();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure ApprovePurchaseOrdersOnChange(Item)
	FormManagement();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddContactFields(Command)
	
	ContactPersonsDataRow = ContactPersonsData.Add();
	AfterContactPersonAddingOnClient(ContactPersonsDataRow.GetID());
	IDsArray = New Array;
	IDsArray.Add(ContactPersonsDataRow.GetID());
	RefreshContactPersonsItems(False, IDsArray);
	RefreshContactPersonsContactInformation(IDsArray);
	CurrentItem = Items["DescriptionContact_" + ContactPersonsDataRow.GetID()];
	
EndProcedure

&AtClient
Procedure PhoneCall(Command)
	CreateEventByCounterparty("PhoneCall", Object.Ref);
EndProcedure

&AtClient
Procedure Email(Command)
	CreateEventByCounterparty("Email", Object.Ref);
EndProcedure

&AtClient
Procedure SMS(Command)
	CreateEventByCounterparty("SMS", Object.Ref);
EndProcedure

&AtClient
Procedure PersonalMeeting(Command)
	CreateEventByCounterparty("PersonalMeeting", Object.Ref);
EndProcedure

&AtClient
Procedure Other(Command)
	CreateEventByCounterparty("Other", Object.Ref);
EndProcedure

&AtClient
Procedure CheckVATNumber(Command)
	
	CheckVATNumberAtServer(True);
	
EndProcedure

&AtClient
Procedure UpdateCounterpartySegments(Command)

	ClearMessages();
	ExecutionResult = GenerateCounterpartySegmentsAtServer();
	If Not ExecutionResult.Status = "Completed" Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckVATNumberAtServer(Manual = False)
	
	If ValueIsFilled(Object.VATNumber) Then
		
		VIESStructure 		= WorkWithVIESServer.VATCheckingResult(Object.VATNumber);
		VIESClientAddress	= VIESStructure.VIESClientAddress;
		VIESClientName		= VIESStructure.VIESClientName;
		VIESQueryDate		= VIESStructure.VIESQueryDate;
		VIESValidationState	= VIESStructure.VIESValidationState;
		
		Items.GroupVATState.Title			= WorkWithVIESServer.VIESStateString(VIESValidationState);
		Items.GroupVATState.TitleTextColor	= WorkWithVIESServer.VIESStateColor(VIESValidationState);
		
	Else
		
		VIESClientAddress		= "";
		VIESClientName			= "";
		VIESQueryDate			= Date(1, 1, 1);
		VIESValidationState		= Enums.VIESValidationStates.EmptyRef();
		
		Items.GroupVATState.Title			= WorkWithVIESServer.VIESStateString(VIESValidationState);
		Items.GroupVATState.TitleTextColor	= WorkWithVIESServer.VIESStateColor(VIESValidationState);
		
		If Manual Then
			CommonClientServer.MessageToUser(Nstr("en = 'VAT ID is required.'; ru = 'Укажите номер плательщика НДС.';pl = 'Numer VAT jest wymagany.';es_ES = 'Se requiere el identificador del IVA.';es_CO = 'Se requiere el identificador de IVA.';tr = 'KDV kodu gerekli.';it = 'P. IVA richiesta.';de = 'USt.-IdNr. ist ein Pflichtfeld.'"),,"Object.VATNumber");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATValidationAttributes()
	
	If FOUseVIESVATNumberValidation Then
		WorkWithVIESServer.FillVATValidationAttributes(ThisObject, Object.Ref);
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteContactPersons(IDsArray)
	
	AttributesToDelete = New Array;
	
	For Each ContactPerson In ContactPersonsData Do
		If IDsArray.Find(ContactPerson.LineNumber) <> Undefined Then
			
			AttributesToDelete.Add(ContactPerson.ContactPersonObject);
			Items.Delete(Items[ContactPerson.ContactInformationGroup]);
			ContactPersonsData.Delete(ContactPerson);
			DeleteCommandsAndFormItems(ContactPerson.ContactInformationGroup);
			
		EndIf;
	EndDo;
	
	ThisObject.ChangeAttributes(,AttributesToDelete);
	
EndProcedure

&AtServer
Procedure RefreshContactPersonsContactInformation(IDsArray)
	
	// StandardSubsystems.ContactInformation
	CIParameters = New Structure;
	CIParameters.Insert("ItemForPlacementName", "ContactInformationGroup");
	CIParameters.Insert("FormItemTitleLocation", FormItemTitleLocation.Left);
	CIParameters.Insert("ObjectIndex", 0);
	For Each ContactPerson In ContactPersonsData Do
		If IDsArray.Find(ContactPerson.LineNumber) <> Undefined Then
			CIParameters.ItemForPlacementName = ContactPerson.ContactInformationGroup;
			CIParameters.ObjectIndex = ContactPerson.LineNumber;
			ContactsManager.OnCreateAtServer(ThisObject, ContactPerson.ContactPerson, CIParameters);
		EndIf;
	EndDo;
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtServer
Procedure OnCreateOnReadAtServer()
	
	ViewStatemenOfAccount = AccessRight("View", Metadata.Reports.StatementOfAccount);
	ViewNetSales = AccessRight("View", Metadata.Reports.NetSales);
	
	// 2. Reading additional informatfion
	ReadAdditionalInformationPanelData();
	
	FillContactPersonContactInformation();
	RefreshContactPersonsItems();
	
	ReadTagsData();
	RefreshTagsItems();
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description);
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual");
	
	Items.DateOfBirth.Visible	= IsIndividual;
	Items.Gender.Visible	= IsIndividual;
	Items.LegalForm.Visible			= Not IsIndividual;
	
	Items.CustomerAcquisitionChannel.Visible = Object.Customer;
	
	Items.DebtBalance.Visible = ViewStatemenOfAccount;
	Items.SalesAmount.Visible = ViewNetSales And Object.Customer;
	Items.LastSale.Visible = ViewNetSales And Object.Customer;
	
	Items.DoOperationsByContracts.Visible = UseContractsWithCounterparties;
	
	Items.GroupPurchaseOrderApproval.Visible =
		Object.Supplier
		And UsePurchaseOrderApproval
		And PurchaseOrdersApprovalType = PredefinedValue("Enum.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty");
	Items.GroupLimitApproval.Enabled = Object.ApprovePurchaseOrders;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormTitle(Form)
	
	Object = Form.Object;
	If Not ValueIsFilled(Object.Ref) Then
		Form.AutoTitle = True;
		Return;
	EndIf;
	
	Form.AutoTitle	= False;
	RelationshipKinds = New Array;
	
	If Object.Customer Then
		RelationshipKinds.Add(NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'"));
	EndIf;
	
	If Object.Supplier Then
		RelationshipKinds.Add(NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'"));
	EndIf;
	
	If Object.OtherRelationship Then
		RelationshipKinds.Add(NStr("en = 'Other relationship'; ru = 'Прочие отношения';pl = 'Inna relacja';es_ES = 'Otras relaciones';es_CO = 'Otras relaciones';tr = 'Diğer';it = 'Altre relazioni';de = 'Andere Beziehung'"));
	EndIf;
	
	If RelationshipKinds.Count() > 0 Then
		Title = Object.Description + " (";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLastCharInString(Title, 2);
	Else	
		Title = Object.Description + " (" + NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
	EndIf;
	
	Title = Title + ")";
	
	Form.Title = Title;
	
EndProcedure

&AtServer
Procedure FillAttributesByFillingText(Val FillingText)
	
	Object.DescriptionFull	= FillingText;
	CurrentItem = Items.DescriptionFull;
	
	GenerateDescriptionAutomatically = True;
	Object.Description	= Object.DescriptionFull;
	
EndProcedure

&AtServer
Procedure FillRegistrationCountry()

	MainCompany = DriveReUse.GetValueOfSetting("MainCompany");
	If ValueIsFilled(MainCompany) Then
		Object.RegistrationCountry = MainCompany.RegistrationCountry;
		Return;
	EndIf;
		
	AllCompanies = Catalogs.Companies.AllCompanies();
	If AllCompanies.Count() = 1 Then
		Object.RegistrationCountry = AllCompanies[0].RegistrationCountry;
	EndIf;

EndProcedure

&AtServer
Procedure FillObjectWithDefaultValues(Parameters)
	
	If Not IsBlankString(Parameters.FillingText) Then
		FillAttributesByFillingText(Parameters.FillingText);
	EndIf;
	
	If Parameters.AdditionalParameters.Property("OperationKind") Then
		Relationship = ContactsClassification.CounterpartyRelationshipTypeByOperationKind(Parameters.AdditionalParameters.OperationKind);
		FillPropertyValues(Object, Relationship, "Customer,Supplier,OtherRelationship");
	EndIf;
	
	FillRegistrationCountry();
	
	Object.PriceKind = Catalogs.PriceTypes.GetMainKindOfSalePrices();
	
EndProcedure

&AtClient
Procedure CreateEventByCounterparty(EventTypeName, Counterparty)
	
	FillingValues = New Structure;
	FillingValues.Insert("EventType", PredefinedValue("Enum.EventTypes." + EventTypeName));
	FillingValues.Insert("Counterparty", Counterparty);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure SetTitleStagesOfPayment()
	TitleStagesOfPayment = PaymentTermsServer.TitleStagesOfPayment(Object);
EndProcedure

#Region PaymentDetails

&AtClient
Procedure SetVisiblePaymentDetails()
	
	UseContracts = UseContractsWithCounterparties AND Object.DoOperationsByContracts;
	
	Items.GroupPaymentDetails.Visible = NOT UseContracts;
	
EndProcedure

&AtClient
Procedure FieldStagesOfPaymentClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Try
		LockFormDataForEdit();
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	FormParameters = New Structure();
	FormParameters.Insert("PaymentMethod", Object.PaymentMethod);
	FormParameters.Insert("DirectDebitMandate", Object.DirectDebitMandate);
	FormParameters.Insert("ProvideEPD", Object.ProvideEPD);
	FormParameters.Insert("PaymentTermsTemplate", Object.PaymentTermsTemplate);
	FormParameters.Insert("UUID", UUID);
	FormParameters.Insert("AddressInTempStorage", PutToTempStorageAtServer());
							
	DefaultContractFields = GetContractByDefaultInformation(Object.ContractByDefault);
	FormParameters.Insert("DirectDebitMandate", DefaultContractFields.DirectDebitMandate);
	FormParameters.Insert("Company", DefaultContractFields.Company);
	FormParameters.Insert("Owner", Object.Ref);
	
	If Object.Supplier AND NOT Object.Customer Then
		FormParameters.Insert("ContractKind", PredefinedValue("Enum.ContractType.WithVendor"));
	ElsIf Object.OtherRelationship AND NOT Object.Customer AND NOT Object.Supplier Then
		FormParameters.Insert("ContractKind", PredefinedValue("Enum.ContractType.Other"));
	Else
		FormParameters.Insert("ContractKind", PredefinedValue("Enum.ContractType.WithCustomer"));
	EndIf;
	
	OpenForm("Catalog.CounterpartyContracts.Form.StagesOfPaymentForm",
		FormParameters,
		ThisObject,,,,
		New NotifyDescription("FieldStagesOfPaymentClickEnd", ThisObject),
		FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure FieldStagesOfPaymentClickEnd(Result, Options) Export
	
	PaymentOptions = Result;
	
	If PaymentOptions <> Undefined Then
		
		Modified = True;
		Object.PaymentMethod = PaymentOptions.PaymentMethod;
		Object.CashAssetType = PaymentOptions.CashAssetType;
		Object.ProvideEPD = PaymentOptions.ProvideEPD;
		Object.PaymentTermsTemplate = PaymentOptions.PaymentTermsTemplate;
		Object.DirectDebitMandate = PaymentOptions.DirectDebitMandate;
		Object.StagesOfPayment.Clear();
		If ValueIsFilled(PaymentOptions.AddressInTempStorage) Then
			FillStagesOfPaymentFromTempStorage(PaymentOptions.AddressInTempStorage);
		EndIf;
		
		SetTitleStagesOfPayment();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillStagesOfPaymentFromTempStorage(AddressInTempStorage)
	
	StructureForTables = GetFromTempStorage(AddressInTempStorage);
	
	Object.StagesOfPayment.Load(StructureForTables.StagesOfPayment);
	Object.EarlyPaymentDiscounts.Load(StructureForTables.EarlyPaymentDiscounts);
	
EndProcedure

&AtServer
Function PutToTempStorageAtServer()
	
	StructureForTables = New Structure;
	StructureForTables.Insert("StagesOfPayment", Object.StagesOfPayment.Unload());
	StructureForTables.Insert("EarlyPaymentDiscounts", Object.EarlyPaymentDiscounts.Unload());
	
	Result = PutToTempStorage(StructureForTables, UUID);
	Return Result;
	
EndFunction

&AtServer
Procedure SetSupplierPriceTypesChoiceParameters(CounterpartyRef)
	
	NewArray = New Array();
	NewArray.Add(Catalogs.Counterparties.EmptyRef());
	If ValueIsFilled(CounterpartyRef) Then
		NewArray.Add(CounterpartyRef);
	EndIf;
	
	ArrayCounterparties = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.Counterparty", ArrayCounterparties);
	
	NewArray = New Array();
	NewArray.Add(NewParameter);
	
	NewParameters = New FixedArray(NewArray);
	Items.SupplierPriceTypes.ChoiceParameters = NewParameters;
	
EndProcedure

#EndRegion

#Region DuplicatesBlocking

// Procedure of processing the results of Duplicate checking closing
//
&AtClient
Procedure OnCloseDuplicateChecking(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ValueIsFilled(ClosingResult.ActionWithExistingObject) Then
				
			ModificationTableAddress = ClosingResult.ModificationTableAddress;
				
		EndIf;
		
		DuplicateRulesIndexTableAddress = ClosingResult.DuplicateRulesIndexTableAddress;
		
		If ClosingResult.ActionWithNewObject = "Create" Then
			
			NotToCheck = New Structure("NotToCheckDuplicates", True);
			ThisObject.Write(NotToCheck);
			ThisObject.Close();
			
		ElsIf ClosingResult.ActionWithNewObject = "Delete" Then
			
			If ValueIsFilled(Object.Ref) Then
				
				Object.DeletionMark = True;
				NotToCheck = New Structure("NotToCheckDuplicates", True);
				ThisObject.Write(NotToCheck);
				ThisObject.Close();
				
			Else
				
				If ChangeDuplicatesDataAtServer(ModificationTableAddress) Then
					
					ThisObject.Modified = False;
					ThisObject.Close();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ChangeDuplicatesDataAtServer(ModificationTableAddress)
	
	Cancel = False;
	ModificationTable = GetFromTempStorage(ModificationTableAddress);
	DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	
	Return Not Cancel;
	
EndFunction

&AtServerNoContext
Function DuplicatesTableStructureAtServer(DuplicateCheckingParameters)
	
	Return DuplicatesBlocking.DuplicatesTableStructure(DuplicateCheckingParameters);
	
EndFunction

#EndRegion

&AtServer
Procedure DeleteCommandsAndFormItems(ItemForPlacementName)
	
	FormAttributeList = ThisObject.GetAttributes();
	
	FirstRun = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" Then
			FirstRun = False;
			Break;
		EndIf;
	EndDo;
	
	If FirstRun Then
		Return;
	EndIf;
	
	If ThisObject.ContactInformationParameters.Property(ItemForPlacementName) Then
			
		FormContactInformationParameters = ThisObject.ContactInformationParameters[ItemForPlacementName];
		AddedItems = FormContactInformationParameters.AddedItems;
		AddedItems.SortByPresentation();
		
		For Each ItemToRemove In AddedItems Do
			
			If ThisObject.Commands.Find(ItemToRemove.Value) <> Undefined Then
				ThisObject.Commands.Delete(ThisObject.Commands[ItemToRemove.Value]);
			EndIf;
			
		EndDo;
		
		FormContactInformationParameters.AddedItems.Clear();
		
	EndIf;
	
EndProcedure

#Region ContactPersons

&AtServer
Procedure FillContactPersonContactInformation()
	
	AttributesToDeleteArray = New Array;
	For Each ContactPerson In ContactPersonsData Do
		AttributesToDeleteArray.Add(ContactPerson.ContactPersonObject);
	EndDo;
	ThisObject.ChangeAttributes(, AttributesToDeleteArray);
	ContactPersonsData.Clear();
		
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ContactPersons.Ref AS ContactPerson,
	|	ContactPersons.Owner AS Owner,
	|	ContactPersons.Position AS Position,
	|	ContactPersons.Description AS Description,
	|	ContactPersons.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
	|INTO TT_Contacts
	|FROM
	|	Catalog.ContactPersons AS ContactPersons
	|WHERE
	|	ContactPersons.Owner = &Owner
	|	AND ContactPersons.Invalid = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Contacts.ContactPerson AS ContactPerson,
	|	TT_Contacts.Description AS Description,
	|	TT_Contacts.Position AS Position
	|FROM
	|	TT_Contacts AS TT_Contacts
	|
	|ORDER BY
	|	TT_Contacts.AdditionalOrderingAttribute,
	|	Description";
	
	Query.SetParameter("Owner", Object.Ref);
	
	QueryResult = Query.Execute();
	
	SelContacts = QueryResult.Select();
	
	Filter = New Structure("ContactPerson");
	
	While SelContacts.Next() Do
		
		Filter.ContactPerson = SelContacts.ContactPerson;
		
		ContactPersonsRow = ContactPersonsData.Add();
		FillPropertyValues(ContactPersonsRow, SelContacts);
		AfterContactPersonAdding(ContactPersonsRow);
		
	EndDo;
	
	If ContactPersonsData.Count() = 0 Then
		
		ContactPersonsRow = ContactPersonsData.Add();
		AfterContactPersonAdding(ContactPersonsRow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterContactPersonAddingOnClient(ContactPersonsRowID)
	
	AfterContactPersonAdding(ContactPersonsData.FindByID(ContactPersonsRowID));
	
EndProcedure

&AtServer
Procedure AfterContactPersonAdding(ContactPersonsRow)
	
	ContactPersonsRow.LineNumber = ContactPersonsData.IndexOf(ContactPersonsRow);
	ContactPersonsRow.ContactInformationGroup = "ContactInformationGroup_" + ContactPersonsData.IndexOf(ContactPersonsRow);
	ContactPersonsRow.ContactPersonObject = "ContactPerson_" + ContactPersonsData.IndexOf(ContactPersonsRow);
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute(ContactPersonsRow.ContactPersonObject,
		New TypeDescription("CatalogObject.ContactPersons"), , True));
	ThisObject.ChangeAttributes(AttributesToAdd);
	
	If ValueIsFilled(ContactPersonsRow.ContactPerson) Then
		ValueToFormAttribute(ContactPersonsRow.ContactPerson.GetObject(), ContactPersonsRow.ContactPersonObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshContactPersonsItems(RefillAll = True, IDsArray = Undefined)
	
	Items.Move(Items.AddContactFields, Items.GroupLeftColum);
	
	If RefillAll Then
		
		DeleteItems = New Array;
		
		For GroupIndex = 0 To Items.Contacts.ChildItems.Count() - 1 Do
			DeleteItems.Add(Items.Contacts.ChildItems[GroupIndex]);
		EndDo;
		For Each DeleteItem In DeleteItems Do
			Items.Delete(DeleteItem);
		EndDo;
		
	EndIf;

	CIKindWidth = 9;
	CommentFieldWidth = 11;
	
	For Each ContactPersonsDataRow In ContactPersonsData Do
		
		If Not RefillAll AND IDsArray.Find(ContactPersonsDataRow.LineNumber) = Undefined Then
			Continue;
		EndIf;
		
		ContactIndex = ContactPersonsDataRow.LineNumber;
		
		ContactGroup = Items.Add("Contact_" + ContactIndex, Type("FormGroup"), Items.Contacts);
		ContactGroup.Type = FormGroupType.UsualGroup;
		ContactGroup.Representation = UsualGroupRepresentation.None;
		ContactGroup.Group = ChildFormItemsGroup.Vertical;
		ContactGroup.ShowTitle = True;
		
		GroupDescriptionContact = Items.Add("GroupDescriptionContact_" + ContactIndex, Type("FormGroup"), ContactGroup);
		GroupDescriptionContact.Type = FormGroupType.UsualGroup;
		GroupDescriptionContact.Representation = UsualGroupRepresentation.None;
		GroupDescriptionContact.Group = ChildFormItemsGroup.AlwaysHorizontal;
		GroupDescriptionContact.ShowTitle = False;
		
		// Contact name
		DescriptionContact = Items.Add("DescriptionContact_" + ContactIndex, Type("FormField"), GroupDescriptionContact);
		DescriptionContact.Type = FormFieldType.InputField;
		DescriptionContact.DataPath = ContactPersonsData[ContactIndex].ContactPersonObject + ".Description";
		DescriptionContact.TitleLocation = FormItemTitleLocation.None;
		DescriptionContact.InputHint = NStr("en = 'Contact name'; ru = 'Наименование контакта';pl = 'Osoba kontaktowa';es_ES = 'Nombre de contacto';es_CO = 'Nombre de contacto';tr = 'İlgili kişi adı';it = 'Nome contatto';de = 'Kontaktname'");
		DescriptionContact.AutoMarkIncomplete = False;
		DescriptionContact.AutoMaxWidth = False;
		DescriptionContact.MaxWidth = 26;
		DescriptionContact.OpenButton = True;
		DescriptionContact.SetAction("Opening", "Attachable_DescriptionContactOpening");
		
		// Position
		PositionContact = Items.Add("PositionContact_" + ContactIndex, Type("FormField"), GroupDescriptionContact);
		PositionContact.Type = FormFieldType.InputField;
		PositionContact.DataPath = ContactPersonsData[ContactIndex].ContactPersonObject + ".Position";
		PositionContact.TitleLocation = FormItemTitleLocation.None;
		PositionContact.InputHint = NStr("en = 'Position'; ru = 'Должность';pl = 'Stanowisko';es_ES = 'Posición';es_CO = 'Posición';tr = 'Pozisyon';it = 'Posizione';de = 'Position'");
		PositionContact.AutoMaxWidth = False;
		PositionContact.MaxWidth = 25;
		PositionContact.OpenButton = True;
		
		GroupCI = Items.Add("ContactInformationGroup_" + ContactIndex, Type("FormGroup"), ContactGroup);
		GroupCI.Type = FormGroupType.UsualGroup;
		GroupCI.Representation = UsualGroupRepresentation.None;
		GroupCI.Group = ChildFormItemsGroup.Vertical;
		GroupCI.ShowTitle = False;
		
		GroupAddCommandsContact = Items.Add("AddCommandsContact_" + ContactIndex, Type("FormGroup"), ContactGroup);
		GroupAddCommandsContact.Type = FormGroupType.UsualGroup;
		GroupAddCommandsContact.Representation = UsualGroupRepresentation.None;
		GroupAddCommandsContact.Group = ChildFormItemsGroup.AlwaysHorizontal;
		GroupAddCommandsContact.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
		GroupAddCommandsContact.ShowTitle = False;
		
	EndDo;
	
	LastContactIndex = ContactPersonsData.Count() - 1;
	Items.Move(Items.AddContactFields,Items["AddCommandsContact_"+LastContactIndex]);
	
EndProcedure

&AtClient
Procedure Attachable_DescriptionContactOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ContactPersonIndex = Number(StrReplace(Item.Name, "DescriptionContact_", ""));
	
	ContactPerson = ThisObject[ContactPersonsData[ContactPersonIndex].ContactPersonObject];
	
	FormParameters = New Structure;
	FormParameters.Insert("ContactPersonIndex", ContactPersonIndex);
	FormParameters.Insert("ContactDescription", Item.EditText);
	FormParameters.Insert("Counterparty", Object.Ref);
	FormParameters.Insert("Position", ContactPerson.Position);
	
	If ValueIsFilled(ContactPerson.Ref) Then
		FormParameters.Insert("Key", ContactPerson.Ref);
	EndIf;
	
	FormParameters.Insert("ContactInformation", ContactPerson.ContactInformation);
	
	If Not ValueIsFilled(Object.Ref) Then
		Notification = New NotifyDescription(
			"ProcessCreateContactPersonQuery",
			ThisObject,
			New Structure("ContactPersonIndex, FormParameters", ContactPersonIndex, FormParameters));
		QueryText = NStr(
			"en = 'To switch to contact creation you must save your work.
			|Click OK to save and continue, or click Cancel to return.'; 
			|ru = 'Для того, чтобы перейти к созданию контакта, необходимо сохранить данные.
			|Нажмите ОК, чтобы сохранить данные и продолжить, или Отмена для возврата.';
			|pl = 'Aby przejść do tworzenia kontaktów, musisz zapisać swoją pracę.
			|Kliknij na OK, aby zapisać i kontynuować, lub kliknij Anuluj, aby wrócić się.';
			|es_ES = 'Para pasar a la creación del contacto usted debe guardar su trabajo.
			|Pulse OK para guardar y continuar o pulse Cancelar para volver.';
			|es_CO = 'Para pasar a la creación del contacto usted debe guardar su trabajo.
			|Pulse OK para guardar y continuar o pulse Cancelar para volver.';
			|tr = 'Kişi oluşturmaya geçmek için çalışmanızı kaydedin.
			|Kaydedip devam etmek için Tamam''a, geri dönmek için İptal''e tıklayın.';
			|it = 'Per spostarsi alla creazione contatto dovete salvare il vostro lavoro.
			|Premete OK per salvare e continuare, o premete Cancel per ritornare.';
			|de = 'Um zur Kontakterstellung zu wechseln, müssen Sie Ihre Arbeit speichern.
			|Klicken Sie auf OK, um zu speichern und fortzufahren, oder auf Abbrechen, um zurückzukehren.'");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.OKCancel);
		Return;
	EndIf;
	
	OpenForm("Catalog.ContactPersons.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ProcessCreateContactPersonQuery(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Write();
		
		If Not ValueIsFilled(Object.Ref) Then
			Return;
		EndIf;
		
		FormParameters = AdditionalParameters.FormParameters;
		FormParameters.Insert("Counterparty", Object.Ref);
		
		OpenForm("Catalog.ContactPersons.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteContactPersonsData(CurrentObject)
	
	SetPrivilegedMode(True);
	
	ContactPersonsToBeNotified = New Array;
	
	For Each RowCP In ContactPersonsData Do
		
		ContactPersonAttribute = ThisObject[RowCP.ContactPersonObject];
		
		If ValueIsFilled(ContactPersonAttribute.Description) Then
			
			ContactPerson = FormAttributeToValue(RowCP.ContactPersonObject);
			ContactPerson.Owner = CurrentObject.Ref;
			ContactPerson.Write();
			ValueToFormAttribute(ContactPerson, RowCP.ContactPersonObject);
			
			If ValueIsFilled(RowCP.ContactPerson) Then
				ContactPersonsToBeNotified.Add(ContactPerson.Ref);
			EndIf;
			
			RowCP.ContactPerson = ContactPerson.Ref;
			
		EndIf;
	EndDo;
	
	CurrentObject.AdditionalProperties.Insert("ContactPersonsToBeNotified", ContactPersonsToBeNotified);
	
EndProcedure

#EndRegion

#Region AdditionalInformationPanel

&AtServer
Procedure ReadAdditionalInformationPanelData()
	
	AdditionalInformationPanel.ReadAdditionalInformationPanelData(ThisObject, Object.Ref);
	
EndProcedure

#EndRegion

#Region Tags

&AtServer
Procedure ReadTagsData()
	
	TagsData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CounterpartiesTags.Tag AS Tag,
		|	CounterpartiesTags.Tag.DeletionMark AS DeletionMark,
		|	CounterpartiesTags.Tag.Description AS Description
		|FROM
		|	Catalog.Counterparties.Tags AS CounterpartiesTags
		|WHERE
		|	CounterpartiesTags.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewTagData	= TagsData.Add();
		URLFS	= "Tag_" + NewTagData.GetID();
		
		NewTagData.Tag				= Selection.Tag;
		NewTagData.DeletionMark		= Selection.DeletionMark;
		NewTagData.TagPresentation	= FormattedStringTagPresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewTagData.TagLength		= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshTagsItems()
	
	FS = TagsData.Unload(, "TagPresentation").UnloadColumn("TagPresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.TagsCloud.Title	= New FormattedString(FS);
	Items.TagsCloud.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteTagsData(CurrentObject)
	
	CurrentObject.Tags.Load(TagsData.Unload(,"Tag"));
	
EndProcedure

&AtServer
Procedure AttachTagAtServer(Tag)
	
	If TagsData.FindRows(New Structure("Tag", Tag)).Count() > 0 Then
		Return;
	EndIf;
	
	TagData = Common.ObjectAttributesValues(Tag, "Description, DeletionMark");
	
	TagsRow = TagsData.Add();
	URLFS = "Tag_" + TagsRow.GetID();
	
	TagsRow.Tag = Tag;
	TagsRow.DeletionMark = TagData.DeletionMark;
	TagsRow.TagPresentation = FormattedStringTagPresentation(TagData.Description, TagData.DeletionMark, URLFS);
	TagsRow.TagLength = StrLen(TagData.Description);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachTagAtServer(Val TagTitle)
	
	Tag = FindCreateTag(TagTitle);
	AttachTagAtServer(Tag);
	
EndProcedure

&AtServerNoContext
Function FindCreateTag(Val TagTitle)
	
	Tag = Catalogs.Tags.FindByDescription(TagTitle, True);
	
	If Tag.IsEmpty() Then
		
		TagObject = Catalogs.Tags.CreateItem();
		TagObject.Description = TagTitle;
		TagObject.Write();
		Tag = TagObject.Ref;
		
	EndIf;
	
	Return Tag;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringTagPresentation(TagDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonClientCached.StyleColor("MinorInscriptionText");
	BaseFont	= CommonClientCached.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(TagDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure TagInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Tags") Then
		AttachTagAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure TagInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachTagAtServer(Text);
		CurrentItem = Items.TagInputField;
	EndIf;
	
EndProcedure

#EndRegion

#Region CounterpartiesChecks

&AtClientAtServerNoContext
Procedure ExecuteAllChecks(Form)
	
	GenerateDuplicateChecksPresentation(Form);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateDuplicateChecksPresentation(Form)
	
	Object = Form.Object;
	ErrorDescription = "";
	
	If Not IsBlankString(Object.TIN) Then
		
		DuplicatesArray = GetCounterpartyDuplicatesServer(TrimAll(Object.TIN), Object.Ref);
		
		DuplicatesCount = DuplicatesArray.Count();
		
		If DuplicatesCount > 0 Then
			
			ErrorDescription = NStr("en = 'Counterparties (%1) with the same TIN found.'; ru = 'Найдены контрагенты (%1) с одинаковым ИНН.';pl = 'Wykryto kontrahentów (%1) z jednakowym NIP-em.';es_ES = 'Se han encontrado contrapartes (%1) con el mismo NIF.';es_CO = 'Se han encontrado contrapartes (%1) con el mismo NIF.';tr = 'Aynı VKN''ye sahip cari hesaplar (%1) bulundu.';it = 'Trovate controparti (%1) con lo stesso codice fiscale.';de = 'Geschäftspartner (%1) mit derselben Steuernummer gefunden.'");
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, 
				DuplicatesCount);
			
		EndIf;
	EndIf;
	
	Form.DuplicateChecksPresentation = New FormattedString(ErrorDescription, , Form.ErrorCounterpartyHighlightColor, , "ShowDuplicates");
	
EndProcedure

&AtServerNoContext
Function GetCounterpartyDuplicatesServer(TIN, ExcludingRef)
	
	Return Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTIN(TIN, ExcludingRef);
	
EndFunction

&AtClientAtServerNoContext
Function IsLegalEntity(CounterpartyKind)
	
	Return CounterpartyKind = PredefinedValue("Enum.CounterpartyType.LegalEntity");
	
EndFunction

&AtServer
Procedure RolesAndBillingDetailsFillCheck(Cancel)
	
	If NOT (Object.Customer OR Object.Supplier OR Object.OtherRelationship) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Please mark the roles of the counterparty (Customer, Supplier, Other relationship)'; ru = 'Укажите роли контрагента (Клиент, Поставщик, другое)';pl = 'Proszę zaznaczyć role kontrahenta (Nabywca, Dostawca, Inna relacja)';es_ES = 'Por favor, marque los roles de la contraparte (Cliente, Proveedor, Otra relación)';es_CO = 'Por favor, marque los roles de la contraparte (Cliente, Proveedor, Otra relación)';tr = 'Lütfen, cari hesap rollerini işaretleyin (Müşteri, Tedarikçi, Diğer)';it = 'Contrassegnare il ruolo della controparte (Cliente, Fornitore, Altro)';de = 'Bitte markieren Sie die Rollen der Geschäftspartner (Kunde, Lieferant, sonstige Beziehung)'"),
			,
			,
			,
			Cancel);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetContractByDefaultInformation(ContractByDefault)
	Return Common.ObjectAttributesValues(ContractByDefault, "Ref, DirectDebitMandate, Company");
EndFunction

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

&AtServer
// Checking "billing by contracts" option and message to user if marks a counterparty as both supplier and customer.
Procedure CheckBillingByContracts()
	
	If Not Object.DoOperationsByContracts And Object.Supplier And Object.Customer Then
		
		IsNew = Object.Ref.IsEmpty();
		UseContracts = Constants.UseContractsWithCounterparties.Get();
		
		If UseContracts And IsNew Then
			MessageText = NStr("en = 'You have selected both Supplier and Customer checkboxes.
					|To be able to apply different conditions to sales and purchases (such as different payment terms or price types),
					|it is recommended to enable tracking AR/AP details by contracts for this counterparty. To do this, next to ""AR/AP details"", select the Contracts checkbox.'; 
					|ru = 'Вы установили флажки ""Поставщик"" и ""Покупатель"" одновременно.
					|Чтобы иметь возможность применять разные условия к продажам и закупкам (например, разные условия оплаты или типы цен),
					|рекомендуется включить отслеживание взаиморасчетов по договорам для данного контрагента. Для этого в разделе ""Взаиморасчеты"" установите флажок ""По договорам"".';
					|pl = 'Są zaznaczone pola wyboru Dostawca i Nabywca.
					|Aby móc zastosować różne warunki do sprzedaży i zakupu (takie jak warunki płatności lub rodzaje cen),
					|zaleca się włączenie śledzenia szczegółów Wn/Ma według kontraktów dla tego kontrahenta. Aby to zrobić, obok z ""Szczegóły Wn/Ma"", zaznacz pole wyboru Kontrakty.';
					|es_ES = 'Ha seleccionado las casillas de verificación Proveedor y Cliente.
					|Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello, junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|es_CO = 'Ha seleccionado las casillas de verificación Proveedor y Cliente.
					|Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello, junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|tr = 'Hem Tedarikçi hem de Müşteri onay kutularını seçtiniz.
					|Satışlara ve satın alımlara farklı koşullar (örneğin, farklı ödeme şartları veya fiyat türleri) uygulayabilmek için,
					|bu cari hesap için alacak/borç ayrıntılarını sözleşmelere göre takip etmeyi etkinleştirmeniz önerilir. Bunun için, ""Alacak/Borç hesapları ayrıntıları""nın yanındaki Sözleşmeler onay kutusunu işaretleyin.';
					|it = 'Avete selezionato entrambe le caselle di controllo Fornitore e Cliente.
					|Per poter applicare condizioni diverse a vendite e acquisti (come termini di pagamento o tipi di prezzi diversi)
					|si consiglia di abilitare il tracciamento dei dettagli Cred/Deb per contratto per questa controparte. Per fare ciò, selezionare accanto a ""Dettagli Cred/Deb"" la casella di controllo Contratti.';
					|de = 'Sie haben die beiden Kontrollkästchen Kunde und Lieferant aktiviert.
					|Um unterschiedliche Kauf- und Verkaufsbedingungen (wie unterschiedliche Zahlungsbedingungen oder Preistypen) verwenden zu können,
					|ist es empfehlenswert die Verfolgung für Offene Posten Kreditoren/Debitoren Details nach Verträgen für diesen Geschäftspartner zu ermöglichen. Dafür aktivieren Sie das Kontrollkästchen Verträge neben ""Offenen Posten Kreditoren/Debitoren Details"".'");
		ElsIf Not UseContracts And IsNew Then
			MessageText = NStr("en = 'You have selected both Supplier and Customer checkboxes. To be able to apply different conditions to sales and purchases (such as different payment terms or price types),
					|it is recommended to enable tracking AR/AP details by contracts for this counterparty. To do this:
					|1. With Administrator privileges, go to Settings > Company and select the ""Use contracts with counterparties"" checkbox.
					|2. In the counterparty card, next to ""AR/AP details"", select the Contracts checkbox.'; 
					|ru = 'Вы установили флажки ""Поставщик"" и ""Покупатель"" одновременно. Чтобы иметь возможность применять разные условия к продажам и закупкам (например, разные условия оплаты или типы цен),
					|рекомендуется включить отслеживание взаиморасчетов по договорам для данного контрагента. Для этого:
					|1. Перейдите в Настройки > Организация и установите флажок ""Использовать договоры с контрагентами"" (требуются права администратора).
					| 2. В карточке контрагента в разделе ""Взаиморасчеты"" установите флажок ""По договорам"".';
					|pl = 'Są zaznaczone pola wyboru Dostawca i Nabywca. Aby mieć możliwość zastosować różne warunki do sprzedaży i zakupu (takie jak warunki płatności lub rodzaje cen),
					|Zaleca się włączyć śledzenie szczegółów Wn/Ma według kontraktów dla tego kontrahenta. Aby zrobić to:
					|1. Z uprawnieniami Administratora, przejdź do Ustawienia > Firma i zaznacz pole wyboru ""Użycie kontraktów z kontrahentami"".
					|2. W karcie kontrahent, zaznacz pole wyboru obok ""Szczegóły Wn/Ma"".';
					|es_ES = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Con privilegios de administrador, vaya a Configuraciones > Empresa y seleccione la casilla de verificación ""Contratos de uso con contrapartes"".
					|2. En el perfil de la contrapartida, junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|es_CO = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Con privilegios de administrador, vaya a Configuraciones > Empresa y seleccione la casilla de verificación ""Contratos de uso con contrapartes"".
					|2. En el perfil de la contrapartida, junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|tr = 'Hem Tedarikçi hem de Müşteri onay kutularını seçtiniz. Satışlara ve satın alımlara farklı koşullar (örneğin, farklı ödeme şartları veya fiyat türleri) uygulayabilmek için,
					|bu cari hesap için alacak/borç ayrıntılarını sözleşmelere göre takip etmeyi etkinleştirmeniz önerilir. Bunun için:
					|1. Yönetici yetkileriyle Ayarlar > İş yeri bölümüne gidip ""Cari hesap sözleşmelerini kullan"" onay kutusunu işaretleyin.
					|2. Cari hesabın kartında, ""Alacak/Borç hesapları ayrıntıları""nın yanındaki Sözleşmeler onay kutusunu işaretleyin.';
					|it = 'Avete selezionato entrambe le caselle di controllo Fornitore e Cliente. Per poter applicare diverse condizioni a vendite e acquisti (come termini di pagamento e tipi di prezzo diversi)
					|si consiglia di abilitare il tracciamento dei dettagli Cred/Deb per contratto per questa controparte. Per fare cio:
					|1. Con i privilegi da Amministratore, andare in Opzioni > Azienda e selezionare la casella di controllo ""Utilizza contratti con le controparti"".
					|2. Nella scheda della controparte, accanto a ""Dettagli Cred/Deb"", selezionare la casella di controllo Contratti.';
					|de = 'Sie haben die beiden Kontrollkästchen Kunde und Lieferant aktiviert. Um unterschiedliche Kauf- und Verkaufsbedingungen (wie unterschiedliche Zahlungsbedingungen oder Preistypen) verwenden zu können,
					|ist es empfehlenswert die Verfolgung für Offene Posten Kreditoren/Debitoren Details nach Verträgen für diesen Geschäftspartner zu ermöglichen. Dafür:
					|1. Mit den Rechten des Administrators, gehen Sie zu Einstellungen > Firma und wählen Sie das Kontrollkästchen ""Verwenden von Verträgen mit Geschäftspartnern"" aus.
					|2. In der Karte des Geschäftspartners aktivieren Sie das Kontrollkästchen Verträge neben ""Offenen Posten Kreditoren/Debitoren Details"".'");
		ElsIf UseContracts And Not IsNew Then
			MessageText = Nstr("en = 'You have selected both Supplier and Customer checkboxes. To be able to apply different conditions to sales and purchases (such as different payment terms or price types),
					|it is recommended to enable tracking AR/AP details by contracts for this counterparty. To do this:
					|1. Click More actions > Allow editing attributes > Check and allow.
					|2. Next to ""AR/AP details"", select the Contracts checkbox.'; 
					|ru = 'Вы установили флажки ""Поставщик"" и ""Покупатель"" одновременно. Чтобы иметь возможность применять разные условия к продажам и закупкам (например, разные условия оплаты или типы цен),
					|рекомендуется включить отслеживание взаиморасчетов по договорам для данного контрагента. Для этого:
					|1. Нажмите Еще > Разрешить редактирование реквизитов > Проверить и разрешить.
					|2. В разделе ""Взаиморасчеты"" установите флажок ""По договорам"".';
					|pl = 'Są zaznaczone pola wyboru Dostawca i Nabywca. Aby móc zastosować różne warunki do sprzedaży i zakupu (takie jak warunki płatności lub rodzaje cen),
					|zaleca się włączenie śledzenia szczegółów Wn/Ma według kontraktów dla tego kontrahenta. Aby to zrobić:
					|1. Kliknij Więcej > Zezwalaj na edycję atrybutów > Sprawdź i zezwól.
					|2. Obok z ""Szczegóły Wn/Ma"", zaznacz pole wyboru Kontrakty.';
					|es_ES = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Haga clic en Más> Permitir la edición de atributos > Revisar y permitir.
					|2. Junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|es_CO = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Haga clic en Más> Permitir la edición de atributos > Revisar y permitir.
					|2. Junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|tr = 'Hem Tedarikçi hem de Müşteri onay kutularını seçtiniz. Satışlara ve satın alımlara farklı koşullar (örneğin, farklı ödeme şartları veya fiyat türleri) uygulayabilmek için,
					|bu cari hesap için alacak/borç ayrıntılarını sözleşmelere göre takip etmeyi etkinleştirmeniz önerilir. Bunun için:
					|1. Diğer işlemler > Öznitelikleri düzenlemeye izin ver > Kontrol et ve izin ver yolunu takip edin.
					|2. ""Alacak/Borç hesapları ayrıntıları""nın yanıdaki Sözleşmeler onay kutusunu işaretleyin.';
					|it = 'Avete selezionato entrambe le caselle di controllo Fornitore e Cliente. Per poter applicare diverse condizioni a vendite e acquisti (come termini di pagamento e tipi di prezzo diversi)
					|si consiglia di abilitare il tracciamento dei dettagli Cred/Deb per contratto per questa controparte. Per fare ciò:
					|1. Cliccare su Più azioni > Permettere modifica degli attributi > Verifica e permetti.
					|2. Accanto a ""Dettagli Cred/Deb"" selezionare la casella di controllo Contratti.';
					|de = 'Sie haben die beiden Kontrollkästchen Kunde und Lieferant aktiviert. Um unterschiedliche Kauf- und Verkaufsbedingungen (wie unterschiedliche Zahlungsbedingungen oder Preistypen) verwenden zu können,
					|ist es empfehlenswert die Verfolgung für Offene Posten Kreditoren/Debitoren Details nach Verträgen für diesen Geschäftspartner zu ermöglichen. Dafür:
					|1. Klicken Sie auf Mehr > Bearbeitung von Attributen gestatten > Überprüfen und gestatten.
					|2. Aktivieren Sie das Kontrollkästchen Verträge neben ""Offenen Posten Kreditoren/Debitoren Details"".'");
		Else
			MessageText = Nstr("en = 'You have selected both Supplier and Customer checkboxes. To be able to apply different conditions to sales and purchases (such as different payment terms or price types),
					|it is recommended to enable tracking AR/AP details by contracts for this counterparty. To do this:
					|1. With Administrator privileges, go to Settings > Company and select the ""Use contracts with counterparties"" checkbox.
					|2. In the counterparty card, сlick More actions > Allow editing attributes > Check and allow.
					|3. Next to ""AR/AP details,"" select the Contracts checkbox.'; 
					|ru = 'Вы установили флажки ""Поставщик"" и ""Покупатель"" одновременно. Чтобы иметь возможность применять разные условия к продажам и закупкам (например, разные условия оплаты или типы цен),
					|рекомендуется включить отслеживание взаиморасчетов по договорам для данного контрагента. Для этого:
					|1. Перейдите в Настройки > Организация и установите флажок ""Использовать договоры с контрагентами"" (требуются права администратора).
					|2. В карточке контрагента нажмите Еще > Разрешить редактирование реквизитов > Проверить и разрешить.
					|3. В разделе ""Взаиморасчеты"" установите флажок ""По договорам"".';
					|pl = 'Są zaznaczone pola wyboru Dostawca i Nabywca. Aby mieć możliwość zastosować różne warunki do sprzedaży i zakupu (takie jak warunki płatności lub rodzaje cen),
					|Zaleca się włączyć śledzenie szczegółów Wn/Ma według kontraktów dla tego kontrahenta. Aby zrobić to:
					|1. Z uprawnieniami Administratora, przejdź do Ustawienia > Firma i zaznacz pole wyboru ""Użycie kontraktów z kontrahentami"".
					|2. W karcie kontrahent, kliknij Więcej > Zezwalaj na edycję atrybutów > Sprawdź i zezwól.
					|3. Zaznacz pole wyboru obok ""Szczegóły Wn/Ma"".';
					|es_ES = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Con privilegios de administrador, vaya a Configuraciones > Empresa y seleccione la casilla de verificación ""Contratos de uso con contrapartes"".
					|2. En el perfil de la contrapartida, haga clic en Más> Permitir la edición de atributos > Revisar y permitir.
					|3. Junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|es_CO = 'Ha seleccionado las casillas de verificación Proveedor y Cliente. Para poder aplicar diferentes condiciones a las ventas y a las compras (como diferentes condiciones de pago o tipos de precio),
					|se recomienda habilitar el seguimiento de los detalles AR/AP por contratos para esta contrapartida. Para ello:
					|1. Con privilegios de administrador, vaya a Configuraciones > Empresa y seleccione la casilla de verificación ""Contratos de uso con contrapartes"".
					|2. En el perfil de la contrapartida, haga clic en Más> Permitir la edición de atributos > Revisar y permitir.
					|3. Junto a ""Detalles AR/AP"", seleccione la casilla de verificación Por contrato.';
					|tr = 'Hem Tedarikçi hem de Müşteri onay kutularını seçtiniz. Satışlara ve satın alımlara farklı koşullar (örneğin, farklı ödeme şartları veya fiyat türleri) uygulayabilmek için,
					|bu cari hesap için alacak/borç ayrıntılarını sözleşmelere göre takip etmeyi etkinleştirmeniz önerilir. Bunun için:
					|1. Yönetici yetkileriyle Ayarlar > İş yeri bölümüne gidip ""Cari hesap sözleşmelerini kullan"" onay kutusunu işaretleyin.
					|2. Cari hesabın kartında, Diğer işlemler > Öznitelikleri düzenlemeye izin ver> Kontrol et ve izin ver yolunu takip edin.
					|3. ""Alacak/Borç hesapları ayrıntıları""nın yanıdaki Sözleşmeler onay kutusunu işaretleyin.';
					|it = 'Avete selezionato entrambe le caselle di controllo Fornitore e Cliente. Per poter applicare diverse condizioni a vendite e acquisti (come termini di pagamento e tipi di prezzo diversi)
					|si consiglia di abilitare il tracciamento dei dettagli Cred/Deb per contratto per questa controparte. Per fare ciò:
					|1. Con i privilegi da Amministratore, andare in Impostazioni > Azienda e selezionare la casella di controllo ""Utilizza contratti con le controparti"".
					|2. Nella scheda della controparte, cliccare su Più azioni > Permettere la modifica degli attributi > Verificare e permettere.
					|3. Accanto a ""Dettagli Cred/Deb"" selezionare la casella di controllo Contratti.';
					|de = 'Sie haben die beiden Kontrollkästchen Kunde und Lieferant aktiviert. Um unterschiedliche Kauf- und Verkaufsbedingungen (wie unterschiedliche Zahlungsbedingungen oder Preistypen) verwenden zu können,
					|ist es empfehlenswert die Verfolgung für Offene Posten Kreditoren/Debitoren Details nach Verträgen für diesen Geschäftspartner zu ermöglichen. Dafür:
					|1. Mit den Rechten des Administrators, gehen Sie zu Einstellungen > Firma und wählen Sie das Kontrollkästchen ""Verwenden von Verträgen mit Geschäftspartnern"" aus.
					|2. In der Karte des Geschäftspartners klicken Sie auf Mehr > Bearbeitung von Attributen gestatten > Überprüfen und gestatten. 
					|3. aktivieren Sie das Kontrollkästchen Verträge neben ""Offenen Posten Kreditoren/Debitoren Details"".'");
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region BackgroundJobs

&AtServer
Function GenerateCounterpartySegmentsAtServer()
	
	CounterpartySegmentsJobID = Undefined;
	
	ProcedureName = "ContactsClassification.ExecuteCounterpartySegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Counterparty segments generation'; ru = 'Создание сегментов контрагентов';pl = 'Generacja segmentów kontrahenta';es_ES = 'Generación de segmentos de contrapartida';es_CO = 'Generación de segmentos de contrapartida';tr = 'Cari hesap segment oluşturma';it = 'Generazione segmenti controparti';de = 'Generierung von Geschäftspartnersegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName,, StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	CounterpartySegmentsJobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(CounterpartySegmentsJobID) Then
			MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(CounterpartySegmentsJobID)
	
	Return TimeConsumingOperations.JobCompleted(CounterpartySegmentsJobID);
	
EndFunction

#EndRegion

#EndRegion