#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SubscriptionPlan") Then
		
		SubscriptionPlan = Parameters.SubscriptionPlan;
		
	Else 
		
		Cancel = True;
		
		Return;
		
	EndIf;
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	EndIf;
	
	If Parameters.Property("Counterparty") Then
		Counterparty = Parameters.Counterparty;
	EndIf;
	
	If Parameters.Property("Contract") Then
		Contract = Parameters.Contract;
	EndIf;
	
	If Parameters.Property("EmailTo") Then
		StartDate = Parameters.StartDate;
	EndIf;
	
	If Parameters.Property("TypeOfDocument") Then
		
		TypeOfDocument = Parameters.TypeOfDocument;
		
		AutoTitle	= False;
		
		If TypeOfDocument = "PurchaseOrder"
			Or TypeOfDocument = "SupplierInvoice" Then
		
			Title		= NStr("en = 'Supplier schedule'; ru = 'График поставщика';pl = 'Harmonogram dostawcy';es_ES = 'Horario del proveedor';es_CO = 'Horario del proveedor';tr = 'Tedarikçi programı';it = 'Programma fornitore';de = 'Lieferantenzeitplan'");
			Items.EmailTo.Visible = False;
			
		Else
			Title		= NStr("en = 'Subscription'; ru = 'Подписка';pl = 'Subskrypcja';es_ES = 'Suscripción';es_CO = 'Suscripción';tr = 'Abonelik';it = 'Abbonamento';de = 'Abonnement'");
		EndIf;
		
	EndIf;
	
	If Parameters.Property("StartDate") Then
		StartDate = Parameters.StartDate;
	EndIf;
	
	If Parameters.Property("EndDate") Then
		EndDate = Parameters.EndDate;
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
	
	If Parameters.Property("IsNew") Then
		
		IsNew = Parameters.IsNew;
		
		If IsNew Then
		
			StringNew = NStr("en = 'create'; ru = 'создать';pl = 'utwórz';es_ES = 'crear';es_CO = 'crear';tr = 'oluştur';it = 'crea';de = 'erstellen'");
			Title = Title + " " + "(" + StringNew + ")";	
		
		EndIf;
		
	EndIf;
	
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	BeforeCloseAtServer(Cancel, MessageText);
EndProcedure

&AtServer
Procedure BeforeCloseAtServer(Cancel, MessageText)
	
	MessageText = "";
	
	CheckContractToDocumentConditionAccordance(MessageText, 
		Contract,  
		SubscriptionPlan, 
		Counterparty, 
		Cancel);	
	
	If MessageText <> "" Then

		If Cancel Then
			
			If TypeOfDocument = "PurchaseOrder"
				Or TypeOfDocument = "SupplierInvoice" Then
				
				MessageText = NStr("en = 'Cannot save the Supplier schedule.'; ru = 'Не удалось сохранить график поставщика.';pl = 'Nie można zapisać harmonogramu dostawcy.';es_ES = 'No se puede guardar el horario del Proveedor.';es_CO = 'No se puede guardar el horario del Proveedor.';tr = 'Tedarikçi programı kaydedilemiyor.';it = 'Impossibile salvare il programma Fornitore.';de = 'Der Lieferantenzeitplan kann nicht gespeichert werden.'") + " " + MessageText;
				
			Else 
				
				MessageText = NStr("en = 'Cannot save the Subscription.'; ru = 'Не удалось записать подписку.';pl = 'Nie można zapisać Subskrypcji.';es_ES = 'No se puede guardar la Suscripción.';es_CO = 'No se puede guardar la Suscripción.';tr = 'Abonelik kaydedilemiyor.';it = 'Impossibile salvare l''Abbonamento.';de = 'Das Abonnement kann nicht gespeichert werden.'") + " " + MessageText;
				
			EndIf;
			
			CommonClientServer.MessageToUser(MessageText, ,"Contract", , Cancel);
			
		Else
			
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

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
Procedure CounterpartyChoiceProcessing(Result, Parameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Counterparty = Result;
	CounterpartyOnChangeAtServer();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	CounterpartyOnChangeAtServer();
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Company, Counterparty, Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	MessageText = "";
	Cancel = False;
	
	If IsNew Then
		
		CheckExistRecord(MessageText, 
			Contract,
			SubscriptionPlan, 
			Counterparty,
			EmailTo,
			Cancel);
			
	EndIf;
		
	CheckAttributesClient(Cancel);
		
	If Cancel Then
		
		If MessageText <> "" Then
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		Return;
		
	EndIf;
		
	ClosingStructure = New Structure;
	ClosingStructure.Insert("Counterparty", Counterparty);
	ClosingStructure.Insert("Contract",     Contract);
	ClosingStructure.Insert("EmailTo",      EmailTo);
	ClosingStructure.Insert("StartDate",    StartDate);
	ClosingStructure.Insert("EndDate",      EndDate);
	Close(ClosingStructure);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	If Counterparty.IsEmpty() Then
		DoOperationsByContracts = False;
	Else
		DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	EndIf;
	
	Items.Contract.Visible = DoOperationsByContracts;
	
EndProcedure

&AtServerNoContext
Procedure CheckExistRecord(MessageText, Contract, SubscriptionPlan, Counterparty, EmailTo, Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TRUE AS Result
	|FROM
	|	InformationRegister.Subscriptions AS Subscriptions
	|WHERE
	|	Subscriptions.SubscriptionPlan = &SubscriptionPlan
	|	AND Subscriptions.Counterparty = &Counterparty
	|	AND Subscriptions.Contract = &Contract
	|	AND Subscriptions.EmailTo = &EmailTo";
	
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("EmailTo", EmailTo);
	Query.SetParameter("SubscriptionPlan", SubscriptionPlan);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If Not QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'Subscription with these settings exist. 
			|Specify settings with another counterparty or contract.'; 
			|ru = 'Подписка с этими настройками уже существует. 
			|Укажите настройки с другим контрагентом или договором.';
			|pl = 'Istnieje subskrypcja z tymi ustawieniami. 
			|Określ ustawienia z innym kontrahentem lub kontraktem.';
			|es_ES = 'Existe una suscripción con estas configuraciones. 
			|Especifique las configuraciones con otra contrapartida o contrato.';
			|es_CO = 'Existe una suscripción con estas configuraciones. 
			|Especifique las configuraciones con otra contrapartida o contrato.';
			|tr = 'Bu ayarlara sahip abonelik mevcut. 
			|Başka bir hesap veya sözleşmeli ayarlar belirtin.';
			|it = 'Esiste un abbonamento con queste impostazioni. 
			|Specificare le impostazioni con un''altra controparte o contratto.';
			|de = 'Abonnement mit diesen Einstellungen ist vorhanden. 
			|Geben Sie Einstellungen mit einem anderen Geschäftspartner oder Vertrag an.'");
		Cancel = True;
		
	EndIf;

EndProcedure

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, SubscriptionPlan, Counterparty, Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		Or Not Counterparty.DoOperationsByContracts Then
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

&AtServer
Procedure CounterpartyOnChangeAtServer()
	
	SetContractVisible();
	
	Contract = GetContractByDefault(Company, Counterparty, TypeOfDocument);
	
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

&AtClient
Procedure CheckAttributesClient(Cancel)
	
	If Not ValueIsFilled(StartDate) Then
		
		TextMessage = NStr("en = 'Start date is required.'; ru = 'Требуется указать дату начала.';pl = 'Wymagana jest data rozpoczęcia.';es_ES = 'Se requiere una fecha de inicio.';es_CO = 'Se requiere una fecha de inicio.';tr = 'Başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio.';de = 'Startdatum ist erforderlich.'");
		
		CommonClientServer.MessageToUser(TextMessage, , "StartDate");
		
		Cancel = True;
		
	EndIf;
	
	If StartDate > EndDate 
		And EndDate <> Date(1, 1, 1) Then
		
		TextMessage = NStr("en = 'The start date is later than the end date. Please correct the dates.'; ru = 'Дата начала не может быть больше даты окончания. Исправьте даты.';pl = 'Data rozpoczęcia nie może być późniejsza niż data zakończenia. Skoryguj daty.';es_ES = 'La fecha del inicio es posterior a la fecha final. Por favor, corrija las fechas.';es_CO = 'La fecha del inicio es posterior a la fecha final. Por favor, corrija las fechas.';tr = 'Başlangıç tarihi bitiş tarihinden ileri. Lütfen, tarihleri düzeltin.';it = 'La data di inizio è successiva alla data di fine. Correggere le date.';de = 'Das Startdatum liegt nach dem Enddatum. Bitte korrigieren Sie die Daten.'");
		
		CommonClientServer.MessageToUser(TextMessage, , "StartDate");
		
		Cancel = True;
		
	EndIf;
		
EndProcedure

#EndRegion
