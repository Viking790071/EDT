
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	Description	= Object.Description;
	
	SetFormConditionalAppearance();
	
	FixedContractAmount	= (Object.Amount <> 0);
	
	If Object.Ref.IsEmpty() Then
		FillObjectWithDefaultValues(Parameters);		
	EndIf;
	
	FunctionalCurrency	= DriveReUse.GetFunctionalCurrency();
	
	SetContractKindsChoiceList();
	SetPriceTypesChoiceList();
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
	EndIf;
	
	If Parameters.Property("Document") Then 
		OpeningDocument	= Parameters.Document;
		Items.Pages.CurrentPage = Items.GroupPrintContract;
	Else
		OpeningDocument	= Undefined;
	EndIf;
	
	Parameters.Property("PrintCounterpartyContract", PrintCounterpartyContract);
	
	If Parameters.Property("FillingValues") Then
		Parameters.FillingValues.Property("IsNotifyCaller", IsNotifyCaller);
	EndIf;
	
	GetBlankParameters();
	ShowDocumentBeginning	= True;
	DocumentCreated		= False;
	GenerateAndShowContract();
	
	UsePurchaseOrderApproval = GetFunctionalOption("UsePurchaseOrderApproval");
	PurchaseOrdersApprovalType = Constants.PurchaseOrdersApprovalType.Get();
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	//Conditional appearance
	SetConditionalAppearance();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	AdditionalParameters.Insert("DeferredInitialization", True);
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	FormManagement();
	
	If PrintCounterpartyContract Then
		PrintCounterpartyContract();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetTitleStagesOfPayment();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PredefinedTemplateRestoration" Then 
		If Parameter = Object.ContractForm Then 
			FilterParameters = New Structure;
			FilterParameters.Insert("FormRefs", Object.ContractForm);
			ParameterArray = Object.EditableParameters.FindRows(FilterParameters);
			For Each String In ParameterArray Do 
				String.Value = "";
			EndDo;
		EndIf;
	EndIf;
	
	If EventName = "ContractTemplateChangeAndRecordAtServer" Then 
		If Parameter = Object.ContractForm Then 
			DocumentCreated = False;
			GetBlankParameters();
			GenerateAndShowContract();
			Modified = True;
			ShowDocumentBeginning = True;
			CurrentParameterClicked = "";
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
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	If FixedContractAmount AND Object.Amount = 0 Then
		
		ErrorText = NStr("en = 'Fill the contract amount.'; ru = 'Не заполнена сумма договора.';pl = 'Wypełnij kwotę kontraktu.';es_ES = 'Rellenar el importe del contrato.';es_CO = 'Rellenar el importe del contrato.';tr = 'Sözleşme tutarını girin.';it = 'Inserire l''importo del contratto.';de = 'Füllen Sie den Vertragsbetrag aus.'");
		CommonClientServer.MessageToUser(
			ErrorText,
			Object.Ref,
			"Object.Amount",
			,
			Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If IsNotifyCaller Then
		Close(New Structure("Contract", Object.Ref));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHadlers

&AtClient
Procedure ContractNoOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure ContractDateOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure SettlementsCurrencyOnChange(Item)
	
	Object.Description = GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	
EndProcedure

&AtClient
Procedure DiscountMarkupKindOnChange(Item)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountMarkupKindClear(Item, StandardProcessing)
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Items.PriceKind.AutoChoiceIncomplete	= True;
		Items.PriceKind.AutoMarkIncomplete		= True;	
	Else
		Items.PriceKind.AutoChoiceIncomplete	= False;
		Items.PriceKind.AutoMarkIncomplete		= False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	Items.ContractForm.AutoMarkIncomplete = False;
	If Modified Then
		DocumentCreated = False;
	EndIf;
	
	If Items.Pages.CurrentPage = Items.GroupPrintContract
		AND Not DocumentCreated Then 
		
		GenerateAndShowContract();
	EndIf;
	
	// StandardSubsystems.Properties
	If ThisObject.PropertiesParameters.Property(CurrentPage.Name)
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesRunDeferredInitialization();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ContractFormOnChange(Item)
	
	If Item.EditText = "" Then
		DocumentCreated = False;
		GenerateAndShowContract();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractFormChoiceDataProcessor(Item, ValueSelected, StandardProcessing)
	
	If ValueIsFilled(Object.ContractForm) Then
		ShowDocumentBeginning = True;
	Else
		ShowDocumentBeginning = False;
	EndIf;
	If Object.ContractForm = ValueSelected Then
		DocumentCreated = True;
		ShowDocumentBeginning = False;
		Return;
	EndIf;
	CurrentParameterClicked = "";
	Object.ContractForm = ValueSelected;
	GetBlankParameters();
	DocumentCreated = False;
	GenerateAndShowContract();
	
EndProcedure

&AtClient
Procedure EditableParametersOnActivateCell(Item)
	
	If ValueIsFilled(Object.ContractForm) Then
		If Item.CurrentData <> Undefined Then
			If Not ShowDocumentBeginning Then
				SelectParameter(Item.CurrentData.ID);
			EndIf;
			ShowDocumentBeginning = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersParameterValueOnChange(Item)
	
	ParameterValue = Item.EditText;
	SetAndWriteParameterValue(ParameterValue, True);
	
EndProcedure

&AtClient
Procedure FixedContractAmountOnChange(Item)
	
	If Not FixedContractAmount Then
		Object.Amount = 0;
	EndIf;
	
	FormManagement();
	
EndProcedure

// Procedure - event handler StartChoice of SupplierPriceTypes input field
//
&AtClient
Procedure SupplierPriceTypesStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Catalog.SupplierPriceTypes.ChoiceForm", New Structure("Counterparty", Object.Owner), Item);

EndProcedure

&AtClient
Procedure SupplierPriceTypesCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Catalog.SupplierPriceTypes.ObjectForm", 
		New Structure("Counterparty, Description", Object.Owner, Item.EditText),
		Item);


EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	SetPriceTypesChoiceList();
	
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

#Region FormCommandsHandlers

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.ValidityStartDate;
	Dialog.Period.EndDate	= Object.ValidityEndDate;
	
	NotifyDescription = New NotifyDescription("SetIntervalCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetIntervalCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		Object.ValidityStartDate	= Result.StartDate;
		Object.ValidityEndDate		= Result.EndDate;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FormManagement()
	
	Items.Amount.Enabled			= FixedContractAmount;
	Items.Amount.AutoMarkIncomplete	= FixedContractAmount;
	
	Items.GroupPurchaseOrderApproval.Visible =
		Object.ContractKind = PredefinedValue("Enum.ContractType.WithVendor")
		And UsePurchaseOrderApproval
		And PurchaseOrdersApprovalType = PredefinedValue("Enum.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty");
	Items.GroupLimitApproval.Enabled = Object.ApprovePurchaseOrders;
	
EndProcedure

&AtServer
Procedure FillSupplierPriceTypes()
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT ALLOWED
	|	CounterpartyPrices.Ref AS Ref
	|FROM
	|	Catalog.SupplierPriceTypes AS CounterpartyPrices
	|WHERE
	|	CounterpartyPrices.Counterparty = &Owner
	|	AND NOT CounterpartyPrices.DeletionMark");
	
	Query.SetParameter("Owner", Object.Owner);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then 
		
		Selection = QueryResult.Select();
		Selection.Next();
		Object.SupplierPriceTypes = Selection.Ref;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

&AtServer
Procedure FillPriceKind(IsNew = False)
	
	If IsNew Then
		
		PriceTypesales = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceTypesales");
		
		If ValueIsFilled(PriceTypesales) Then
			
			Object.PriceKind = PriceTypesales;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillObjectWithDefaultValues(Parameters)
		
	FillPriceKind(True);
	FillSupplierPriceTypes();
	
	If Not ValueIsFilled(Object.Company) Then
		
		CompanyByDefault = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
		If ValueIsFilled(CompanyByDefault) Then
			Object.Company = CompanyByDefault;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Object.SettlementsCurrency) Then
		Object.SettlementsCurrency	= FunctionalCurrency;
	EndIf;
	
	If Not IsBlankString(Parameters.FillingText) Then
		Object.ContractNo	= Parameters.FillingText;
		Object.Description	= GenerateDescription(Object.ContractNo, Object.ContractDate, Object.SettlementsCurrency);
	EndIf;
	
	SetTitleStagesOfPayment();
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateDescription(ContractNo, ContractDate, SettlementsCurrency)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '#%1, dated %2 (%3)'; ru = '#%1, от %2 (%3)';pl = '#%1, przestarzały %2 (%3)';es_ES = '#%1, fechado %2 (%3)';es_CO = '#%1, fechado %2 (%3)';tr = '#%1, tarih %2 (%3)';it = '#%1, con data %2 (%3)';de = 'Nr %1, datiert %2 (%3)'"),
		TrimAll(ContractNo),
		?(ValueIsFilled(ContractDate), TrimAll(String(Format(ContractDate, "DLF=D"))), ""),
		TrimAll(String(SettlementsCurrency)));
	
EndFunction

&AtServer
Procedure SetContractKindsChoiceList()
	
	If Constants.SendGoodsOnConsignment.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.WithAgent);
	EndIf;
	
	If Constants.AcceptConsignedGoods.Get() Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.FromPrincipal);
	EndIf;
	
	If GetFunctionalOption("CanReceiveSubcontractingServices") Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.SubcontractingServicesReceived);
	EndIf;
	
	// begin Drive.FullVersion
	
	If GetFunctionalOption("CanProvideSubcontractingServices") Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.SubcontractingServicesProvided);
	EndIf;
	
	// end Drive.FullVersion 
	
	If GetFunctionalOption("UsePaymentProcessors") Then
		Items.ContractKind.ChoiceList.Add(Enums.ContractType.PaymentProcessor);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Print the contract. If the parameter is blank - display its title in the tooltip.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EditableParametersValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue		= New DataCompositionField("EditableParameters.ValueIsFilled");
	ItemFilter.ComparisonType	= DataCompositionComparisonType.Equal;
	ItemFilter.RightValue		= False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableTabularSectionTextColor);
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("EditableParameters.Presentation"));
	
	SetDirectDebitMandateVisible();
EndProcedure

&AtServer
Procedure SetDirectDebitMandateVisible()
	If Object.PaymentMethod = Catalogs.PaymentMethods.DirectDebit Then
		Items.DirectDebitMandate.Visible = True;
	Else
		Items.DirectDebitMandate.Visible = False;
		Object.DirectDebitMandate = Undefined;
	EndIf;
EndProcedure

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Object.Company, ThisForm, "PriceKind");
	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorGrey	= StyleColors.InaccessibleCellTextColor;
	ColorBlack	= StyleColors.TitleColorSettingsGroup;
	
	//EditableParametersValue
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("EditableParameters.ValueIsFilled");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorGrey);
	ItemAppearance.Appearance.SetParameterValue("Text", New DataCompositionField("EditableParameters.Presentation"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EditableParametersValue");
	FieldAppearance.Use = True;
	
	//EditableParametersValue
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("EditableParameters.ValueIsFilled");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorBlack);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EditableParametersValue");
	FieldAppearance.Use = True;
	
EndProcedure

&AtServer
Procedure SetTitleStagesOfPayment()
	TitleStagesOfPayment = PaymentTermsServer.TitleStagesOfPayment(Object);
EndProcedure

#EndRegion
	
#Region PrintContract
	
&AtServer
Procedure GenerateAndShowContract()
	
	If Not DocumentCreated Then
		
		EditableParameters.Clear();
		FilterParameters = New Structure("FormRefs", Object.ContractForm);
		ArrayInfobaseParameters = Object.InfobaseParameters.FindRows(FilterParameters);
		For Each Parameter In ArrayInfobaseParameters Do
			NewRow = EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.Parameter = Parameter.Parameter;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		ArrayEditedParameters = Object.EditableParameters.FindRows(FilterParameters);
		For Each Parameter In ArrayEditedParameters Do
			NewRow = EditableParameters.Add();
			NewRow.Presentation = Parameter.Presentation;
			NewRow.Value = Parameter.Value;
			NewRow.ID = Parameter.ID;
			NewRow.LineNumber = Parameter.LineNumber;
		EndDo;
		
		GeneratedDocument = DriveCreationOfPrintedFormsOfContract.GetGeneratedContractHTML(Object, OpeningDocument, EditableParameters);
		If ContractHTMLDocument = GeneratedDocument Then
			DocumentCreated = True;
		EndIf;
		ContractHTMLDocument = GeneratedDocument;
		
		FilterParameters = New Structure("Parameter", PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Facsimile"));
		Rows = EditableParameters.FindRows(FilterParameters);
		For Each String In Rows Do
			ID = String.GetID();
			EditableParameters.Delete(EditableParameters.FindByID(ID));
		EndDo;
		
		FilterParameters.Parameter = PredefinedValue("Enum.ContractsWithCounterpartiesTemplatesParameters.Logo");
		Rows = EditableParameters.FindRows(FilterParameters);
		For Each String In Rows Do
			ID = String.GetID();
			EditableParameters.Delete(EditableParameters.FindByID(ID))
		EndDo;
		
		For Each String In EditableParameters Do
			If ValueIsFilled(String.Value) Then
				String.ValueIsFilled = True;
			Else
				String.ValueIsFilled = False;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Procedure GetBlankParameters()
	
	FilterParameters = New Structure("FormRefs", Object.ContractForm);
	ObjectEditedParameters		= Object.EditableParameters.FindRows(FilterParameters);
	ObjectInfobaseParameters	= Object.InfobaseParameters.FindRows(FilterParameters);
	
	For Each Parameter In ObjectEditedParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		If Object.ContractForm.EditableParameters.FindRows(FilterParameters).Count() <> 0 Then
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.EditableParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.EditableParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter In Object.ContractForm.EditableParameters Do
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.EditableParameters.FindRows(FilterParameters).Count() > 0 Then 
			Continue;
		EndIf;
		NewRow = Object.EditableParameters.Add();
		NewRow.FormRefs		= Object.ContractForm;
		NewRow.Presentation	= Parameter.Presentation;
		NewRow.ID			= Parameter.ID;
	EndDo;
	
	For Each Parameter In ObjectInfobaseParameters Do
		FilterParameters = New Structure("ID", Parameter.ID);
		Rows = Object.ContractForm.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() <> 0 Then
			Parameter.Presentation = Rows[0].Presentation;
			Continue;
		EndIf;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		Rows = Object.InfobaseParameters.FindRows(FilterParameters);
		If Rows.Count() > 0 Then 
			Object.InfobaseParameters.Delete(Rows[0]);
		EndIf;
	EndDo;
	
	For Each Parameter In Object.ContractForm.InfobaseParameters Do 
		FilterParameters = New Structure("FormRefs, ID", Object.ContractForm, Parameter.ID);
		If Object.InfobaseParameters.FindRows(FilterParameters).Count() > 0 Then
			Continue;
		EndIf;
		NewRow = Object.InfobaseParameters.Add();
		NewRow.FormRefs		= Object.ContractForm;
		NewRow.Presentation	= Parameter.Presentation;
		NewRow.ID			= Parameter.ID;
		NewRow.Parameter	= Parameter.Parameter;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectParameter(Parameter)
	
	If Not DocumentCreated Then
		Return;
	EndIf;
	
	document = Items.ContractHTMLDocument.Document;
	
	If ValueIsFilled(CurrentParameterClicked) Then
		lastParameter = document.getElementById(CurrentParameterClicked);
		If lastParameter.className = "Filled" Then 
			lastParameter.style.backgroundColor = "#FFFFFF";
		ElsIf lastParameter.className = "Empty" Then 
			lastParameter.style.backgroundColor = "#DCDCDC";
		EndIf;
	EndIf;
	
	chosenParameter = document.getElementById(Parameter);
	If chosenParameter <> Undefined Then
		chosenParameter.style.backgroundColor = "#CCFFCC";
		chosenParameter.scrollIntoView();
		
		CurrentParameterClicked = Parameter;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractHTMLDocumentDocumentCreated(Item)
	
	document = Items.ContractHTMLDocument.Document;
	EditedParametersOnPage = document.getElementsByName("parameter");
	
	Iterator = 0;
	For Each Parameter In EditedParametersOnPage Do 
		FilterParameters = New Structure("ID", Parameter.id);
		String = EditableParameters.FindRows(FilterParameters);
		If String.Count() > 0 Then 
			RowIndex = EditableParameters.IndexOf(String[0]);
			Shift = Iterator - RowIndex;
			If Shift <> 0 Then 
				EditableParameters.Move(RowIndex, Shift);
			EndIf;
		EndIf;
		Iterator = Iterator + 1;
	EndDo;
	
	DocumentCreated = True;
	
EndProcedure

&AtServer
Function ThisIsInfobaseParameter(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters"), True, False);
	
EndFunction

&AtServer
Function ThisIsAdditionalAttribute(Parameter)
	
	Return ?(TypeOf(Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"), True, False);
	
EndFunction

&AtServer
Function GetParameterValue(Parameter, Presentation, ID)
	
	If ThisIsInfobaseParameter(Parameter) Then
		Return DriveCreationOfPrintedFormsOfContract.GetParameterValue(Object, , Parameter, Presentation);
	ElsIf ThisIsAdditionalAttribute(Parameter) Then
		Return DriveCreationOfPrintedFormsOfContract.GetAdditionalAttributeValue(Object, OpeningDocument, Parameter);
	Else
		Return DriveCreationOfPrintedFormsOfContract.GetFilledFieldValueOnGeneratingPrintedForm(Object, ID);
	EndIf;
	
EndFunction

&AtClient
Procedure EditableParametersOnStartEdit(Item, NewRow, Copy)
	
	If Not ValueIsFilled(CurrentParameterClicked) Then
		SelectParameter(Item.CurrentData.ID);
	EndIf;
	
	Rows = EditableParameters.FindRows(New Structure("ID", CurrentParameterClicked));
	If Rows.Count() > 0 Then
		Rows[0].ValueIsFilled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersOnEditEnd(Item, NewRow, CancelEdit)
	
	Rows = EditableParameters.FindRows(New Structure("ID", CurrentParameterClicked));
	If Rows.Count() > 0 Then
		If ValueIsFilled(Rows[0].Value) Then
			Rows[0].ValueIsFilled = True;
		Else
			Rows[0].ValueIsFilled = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EditableParametersParameterValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Parameter = Items.EditableParameters.CurrentData;
	ParameterValue = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
	Items.EditableParameters.CurrentData.Value = ParameterValue;
	
	SetAndWriteParameterValue(ParameterValue, False);
	
EndProcedure

&AtClient
Procedure SetAndWriteParameterValue(ParameterValue, WriteValue)
	
	document = Items.ContractHTMLDocument.Document;
	chosenParameter = document.getElementById(CurrentParameterClicked);
	
	If ValueIsFilled(ParameterValue) Then
		chosenParameter.innerText = ParameterValue;
		chosenParameter.className = "Filled";
		Items.EditableParameters.CurrentData.ValueIsFilled = True;
	Else
		chosenParameter.innerText = "__________";
		chosenParameter.className = "Empty";
		Items.EditableParameters.CurrentData.ValueIsFilled = False;
	EndIf;
	
	WorkingTable = Undefined;
	Parameter = Items.EditableParameters.CurrentData;
	If ThisIsInfobaseParameter(Parameter.Parameter) OR ThisIsAdditionalAttribute(Parameter.Parameter) Then
		WorkingTable = Object.InfobaseParameters;
		If WriteValue Then
			ParameterValueInInfobase = GetParameterValue(Parameter.Parameter, Parameter.Presentation, Parameter.ID);
			If ParameterValue = ParameterValueInInfobase Then
				WriteValue = False;
			EndIf;
		EndIf;
	Else
		WorkingTable = Object.EditableParameters;
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ID", CurrentParameterClicked);
	Rows = EditableParameters.FindRows(FilterParameters);
	If Rows.Count() > 0 Then 
		ParameterIndex = Rows[0].LineNumber - 1;
	Else
		ParameterIndex = Undefined;
	EndIf;
	
	If ParameterIndex = Undefined Then
		Return;
	EndIf;
	
	If WriteValue Then
		WorkingTable[ParameterIndex].Value = ParameterValue;
	Else
		WorkingTable[ParameterIndex].Value = "";
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PrintCounterpartyContract() Export
	
	Contract = ContractHTMLDocument;
	
	If Not ValueIsFilled(Object.ContractForm) Then
		ErrorText = NStr("en = 'Fill the contract print template.'; ru = 'Заполните бланк договора для печати.';pl = 'Wypełnij szablon wydruku umowy.';es_ES = 'Rellenar la plantilla de impresión del contrato.';es_CO = 'Rellenar la plantilla de impresión del contrato.';tr = 'Sözleşme baskı şablonu doldur.';it = 'Compilare il modello di stampa del contratto.';de = 'Gedrückte Vertragsvorlage ausfüllen'");
		CommonClientServer.MessageToUser(
			ErrorText,
			Object.Ref,
			"Object.ContractForm");
		Return;
	EndIf;
	
	Items.Pages.CurrentPage = Items.GroupPrintContract;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("FormRefs", Object.ContractForm);
	
	EditedParametersArray		= Object.EditableParameters.FindRows(FilterParameters);
	AllEditedParametersFilled	= True;
	
	For Each String In EditedParametersArray Do 
		If Find(Contract, String.ID) <> 0 Then
			If Not ValueIsFilled(String.Value) Then 
				AllEditedParametersFilled = False;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If Not AllEditedParametersFilled Then
		ShowQueryBox(New NotifyDescription("PrintCounterpartyContractQuestion", 
			DriveClient,
			New Structure("PrintingSource", ThisObject)),
			NStr("en = 'Not all manually edited fields are filled in, continue printing?'; ru = 'Не все редактируемые вручную поля заполнены, продолжить печать?';pl = 'Nie wszystkie pola edytowane ręcznie zostały wypełnione, kontynuować drukowanie?';es_ES = 'No todos los campos manualmente editados están rellenados, ¿continuar a imprimir?';es_CO = 'No todos los campos manualmente editados están rellenados, ¿continuar a imprimir?';tr = 'Manuel olarak düzenlenen tüm alanlar doldurulmadı. Yazdırmaya devam edilsin mi?';it = 'Non tutti i campi modificabili manualmente sono stati compilati, continuare a stampare?';de = 'Nicht alle manuell bearbeiteten Felder sind ausgefüllt, weiter drucken?'"), 
			QuestionDialogMode.YesNo);
	Else
		DriveClient.PrintCounterpartyContractEnd(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

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

&AtClient
Procedure FieldStagesOfPaymentClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Try
		LockFormDataForEdit();
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	FormOptions = New Structure();
	FormOptions.Insert("PaymentMethod", Object.PaymentMethod);
	FormOptions.Insert("CashAssetType", Object.CashAssetType);
	FormOptions.Insert("ProvideEPD", Object.ProvideEPD);
	FormOptions.Insert("PaymentTermsTemplate", Object.PaymentTermsTemplate);
	FormOptions.Insert("UUID", UUID);
	FormOptions.Insert("AddressInTempStorage", PutToTempStorageAtServer());
	FormOptions.Insert("ContractKind", Object.ContractKind);
	FormOptions.Insert("DirectDebitMandate", Object.DirectDebitMandate);
	FormOptions.Insert("Company", Object.Company);
	FormOptions.Insert("Owner", Object.Owner);
	
	PaymentOptions = Undefined;
	
	OpenForm(
		"Catalog.CounterpartyContracts.Form.StagesOfPaymentForm", 
		FormOptions, ThisForm,,,,
		New NotifyDescription("FieldStagesOfPaymentClickEnd", ThisObject),
		FormWindowOpeningMode.LockWholeInterface);
		
	
EndProcedure
	
&AtClient
Procedure FieldStagesOfPaymentClickEnd(Result, Options) Export
	
	PaymentOptions = Result;
	
	If PaymentOptions <> Undefined Then
		
		Modified = True;
		Object.PaymentMethod = PaymentOptions.PaymentMethod;
		Object.DirectDebitMandate = PaymentOptions.DirectDebitMandate;
		Object.CashAssetType = PaymentOptions.CashAssetType;
		Object.ProvideEPD = PaymentOptions.ProvideEPD;
		Object.PaymentTermsTemplate = PaymentOptions.PaymentTermsTemplate;
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
	
	Return PutToTempStorage(StructureForTables);
	
EndFunction

&AtClient
Procedure ContractKindOnChange(Item)
	
	SetTitleStagesOfPayment();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	SetDirectDebitMandateVisible();	
EndProcedure

#EndRegion