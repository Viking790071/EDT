
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SubscriptionPlan") Then
		
		If Record.SubscriptionPlan <> Parameters.SubscriptionPlan Then
			Record.SubscriptionPlan = Parameters.SubscriptionPlan;
		EndIf;
		
		Company = Record.SubscriptionPlan.Company;
		
		Items.SubscriptionPlan.Visible = False;
		
	EndIf;
	
	If Parameters.Property("Counterparty") Then
		
		If Record.Counterparty <> Parameters.Counterparty Then
			Record.Counterparty = Parameters.Counterparty;
		EndIf;
		
		Items.Counterparty.Visible = False;
		
	EndIf;
	
	If Parameters.Property("TypeOfDocument") Then
		
		TypeOfDocument = Parameters.TypeOfDocument;
		
		If TypeOfDocument = "PurchaseOrder"
			Or TypeOfDocument = "SupplierInvoice" Then
		
		
			Items.EmailTo.Visible = False;
		
		EndIf;
		
	EndIf;
	
	If Parameters.Property("StartDate") Then
		
		Record.StartDate = Parameters.StartDate;
		
	EndIf;
	
	If Parameters.Property("EndDate") Then
		
		Record.EndDate = Parameters.EndDate;
		
	EndIf;
	
	If Parameters.Property("IsDimensionsReadOnly") 
		And Parameters.IsDimensionsReadOnly Then
		
		Items.Counterparty.ReadOnly	= True;
		Items.Contract.ReadOnly		= True;
		
	EndIf;
	
	If Parameters.Property("IsResourcesReadOnly") 
		And Parameters.IsResourcesReadOnly Then
		
		Items.StartDate.ReadOnly	= True;
		Items.EndDate.ReadOnly		= True;
		
	EndIf;
	
	SetContractVisible();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	MessageText = "";
	
	CheckContractToDocumentConditionAccordance(
		MessageText, 
		CurrentObject.Contract,  
		CurrentObject.SubscriptionPlan, 
		CurrentObject.Counterparty, 
		Cancel);	
	
	If MessageText <> "" Then

		If Cancel Then
			MessageText = NStr("en = 'Cannot write the Subscription.'; ru = 'Не удалось записать подписку.';pl = 'Nie można zapisać Subskrypcji';es_ES = 'No se puede escribir la Suscripción.';es_CO = 'No se puede escribir la Suscripción.';tr = 'Abonelik yazılamıyor.';it = 'Impossibile registrare l''Abbonamento.';de = 'Kann das Abonnement nicht schreiben.'") + " " + MessageText;
			CommonClientServer.MessageToUser(MessageText,,"Contract", "Record", Cancel);
		Else
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SubscriptionPlanOnChange(Item)
	SubscriptionPlanOnChangeAtServer();
EndProcedure

&AtClient
Procedure CounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOfDocument = "PurchaseOrder"
		Or TypeOfDocument = "SupplierInvoice" Then
		
		Filter = New Structure("Supplier", True);
		
	Else
		
		Filter = New Structure("Customer", True);
		
	EndIf;	
	
	NotifyDescription = New NotifyDescription("CounterpartyChoiceProcessing", ThisObject);
	
	OpenForm("Catalog.Counterparties.ChoiceForm", New Structure("Filter, ChoiceMode", Filter, True),,,,,NotifyDescription);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	CounterpartyOnChangeAtServer();
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Company, Record.Counterparty, Record.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	If Record.Counterparty.IsEmpty() Then
		DoOperationsByContracts = False;
	Else
		DoOperationsByContracts = Common.ObjectAttributeValue(Record.Counterparty, "DoOperationsByContracts");
	EndIf;
	
	Items.Contract.Visible = DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SubscriptionPlanOnChangeAtServer()
	
	Company = Record.SubscriptionPlan.Company;
	
	Record.Contract = ?(DoOperationsByContracts, 
		GetContractByDefault(Company, Record.Counterparty, TypeOfDocument), 
		Catalogs.CounterpartyContracts.EmptyRef());
	
EndProcedure

&AtClient
Procedure CounterpartyChoiceProcessing(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Record.Counterparty = Result;
	CounterpartyOnChangeAtServer();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeAtServer()
	
	SetContractVisible();
	
	Record.Contract = GetContractByDefault(Company, Record.Counterparty, TypeOfDocument);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Company, Counterparty, TypeOfDocument)
	
	If TypeOfDocument = "PurchaseOrder" Then
		Document = Documents.PurchaseOrder.EmptyRef();
	ElsIf TypeOfDocument = "SupplierInvoice" Then
		Document = Documents.SupplierInvoice.EmptyRef();
	Else
		Document = Documents.SalesInvoice.EmptyRef();
	EndIf;
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtServerNoContext
Function GetChoiceFormParameters(Company, Counterparty, Contract)
	
	Document = Documents.SalesInvoice.EmptyRef();
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, SubscriptionPlan, Counterparty, Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		Return;
	EndIf;
	
	Document = Documents.SalesInvoice.EmptyRef();
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	
	If GetFunctionalOption("CheckContractsOnPosting")
		AND Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, SubscriptionPlan.Company, Counterparty, ContractKindsList) Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion 