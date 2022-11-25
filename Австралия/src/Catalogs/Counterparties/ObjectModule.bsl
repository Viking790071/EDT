#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") AND Not IsFolder Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	EndIf;
	
	FillByDefault();
	
	If Not IsFolder Then
		
		GLAccountCustomerSettlements	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsReceivable");
		CustomerAdvancesGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CustomerAdvances");
		GLAccountVendorSettlements		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable");
		VendorAdvancesGLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvancesToSuppliers");
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not Catalogs.CounterpartiesAccessGroups.AccessGroupsAreUsed() Then
		NoncheckableAttributeArray.Add("AccessGroup");
	EndIf;
	
	If IsFolder Then
		
		NoncheckableAttributeArray.Add("PaymentMethod");
		NoncheckableAttributeArray.Add("SettlementsCurrency");
		
	ElsIf Not ValueIsFilled(PaymentMethod) Then
		
		Message = New UserMessage;
		Message.Text = Nstr("en = '""Payment method"" is not filled'; ru = 'Поле ""Способ оплаты"" не заполнено';pl = '""Metoda płatności"" nie jest wypełniona';es_ES = 'No se rellena la ""Forma de pago"".';es_CO = 'No se rellena la ""Forma de pago"".';tr = '""Ödeme yöntemi"" doldurulmadı';it = '""Metodo di pagamento"" non compilato';de = '""Zahlungsmethode"" ist nicht aufgefüllt'");
		Message.Field = "TitleStagesOfPayment";
		Message.Message();
		
		Cancel = True;
		NoncheckableAttributeArray.Add("PaymentMethod");
		
	EndIf;
	
	If Not IsFolder And DoOperationsByContracts Then
		NoncheckableAttributeArray.Add("SettlementsCurrency");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	// 1. Actions which are always executed, including the exchange of data
	
	AdditionalProperties.Insert("NeedToWriteInRegisterOnWrite", False);
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsNew() And Not IsFolder Then
		CheckChangePossibility(Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	If Not (AdditionalProperties.Property("RegisterCounterpartyDuplicates") AND AdditionalProperties.RegisterCounterpartyDuplicates = False) Then
		RegisterCounterpartyDuplicates();
	EndIf;
		
	If Not IsFolder AND IsNew() Then
		CreationDate = CurrentSessionDate();
	EndIf;
	
	If Not IsFolder Then
		
		GenerateBasicInformation();

		For Each Stage In StagesOfPayment Do
			If Stage.BaselineDate.IsEmpty() Then
				Stage.BaselineDate = Enums.BaselineDateForPayment.PostingDate;
			EndIf;
		EndDo;
		
	EndIf;
	
	If NOT IsFolder AND NOT IsNew() Then
		AdditionalProperties.Insert("UpdateContracts", True);
	EndIf;
	
	RefTreaty = Undefined;
	
	// Fill default contract: substitute any existing or create a new
	If Not IsFolder AND Not ValueIsFilled(ContractByDefault) Then
		
		NeedCreateContract	= True;
		
		If Not IsNew() Then
			
			Query = New Query;
			Query.Text = 
				"SELECT ALLOWED TOP 1
				|	CounterpartyContracts.Ref AS Contract
				|FROM
				|	Catalog.CounterpartyContracts AS CounterpartyContracts
				|WHERE
				|	CounterpartyContracts.Owner = &Owner
				|	AND CounterpartyContracts.DeletionMark = FALSE
				|
				|ORDER BY
				|	CounterpartyContracts.ContractNo DESC";
			
			Query.SetParameter("Owner", Ref);
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				ContractByDefault = Selection.Contract;
				
				NeedCreateContract = False;
				
			EndIf;
			
		EndIf;
		
		If NeedCreateContract Then
			ContractByDefault = Catalogs.CounterpartyContracts.GetRef();
			AdditionalProperties.Insert("NewMainContract", ContractByDefault);
		EndIf;
		
	EndIf;
	
	BringDataToConsistentState();
	
	Catalogs.InventoryOwnership.UpdateOnCounterpartyWrite(ThisObject);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If AdditionalProperties.NeedToWriteInRegisterOnWrite Then
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, TIN, False);
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Create a counterparty contract by reference created in the event BeforeWrite()
	If Not IsFolder AND AdditionalProperties.Property("NewMainContract") Then
		
		ContractObject = Catalogs.CounterpartyContracts.CreateItem();
		ContractObject.AdditionalProperties.Insert("IsNewMainContract", True);
		ContractObject.Fill(Ref);
		
		ContractObject.SetNewObjectRef(AdditionalProperties.NewMainContract);
		ContractObject.Write();
		
		AdditionalProperties.Delete("NewMainContract");
		
	EndIf;
	
	If AdditionalProperties.Property("UpdateContracts") AND AdditionalProperties.UpdateContracts Then
		Catalogs.CounterpartyContracts.UpdateContractsFromCounterparty(Ref);
	EndIf;
	
	// Duplicate rules index
	If AdditionalProperties.Property("DuplicateRulesIndexTableAddress") Then
		DuplicateRulesIndexTable = GetFromTempStorage(AdditionalProperties.DuplicateRulesIndexTableAddress);
		AdditionalProperties.Insert("DuplicateRulesIndexTable", DuplicateRulesIndexTable);
	Else
		DuplicatesBlocking.PrepareDuplicateRulesIndexTable(Ref, AdditionalProperties);
	EndIf;
	
	If AdditionalProperties.Property("ModificationTableAddress") Then
		ModificationTable = GetFromTempStorage(AdditionalProperties.ModificationTableAddress);
		DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	EndIf;
	
	DriveServer.ReflectDuplicateRulesIndex(AdditionalProperties, Ref, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If Not IsFolder Then
		BankAccountByDefault	= Undefined;
		ContractByDefault		= Undefined;
		ContactPerson			= Undefined;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteDuplicateRegistrationBeforeDelete();
	
EndProcedure

#EndRegion

#Region Interface

// Procedure fills an auxiliary attribute "BasicInformation"
//
Procedure GenerateBasicInformation() Export
	
	RowsArray = New Array;
	
	If Not IsBlankString(DescriptionFull) Then
		RowsArray.Add(DescriptionFull);
	EndIf;
	
	If Not IsBlankString(TIN) Then
		RowsArray.Add(NStr("en = 'TIN'; ru = 'ИНН';pl = 'NIP';es_ES = 'NIF';es_CO = 'NIF';tr = 'VKN';it = 'Cod.Fiscale';de = 'Steuernummer'") + " " + TIN);
	EndIf;
	
	CI = ContactInformation.Unload();
	CI.Sort("Kind");
	For Each RowCI In CI Do
		If IsBlankString(RowCI.Presentation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowCI.Presentation);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ContactPersons.Description AS Description,
	|	ContactPersons.ContactInformation.(
	|		Presentation AS Presentation,
	|		Kind AS KindCI
	|	)
	|FROM
	|	Catalog.ContactPersons AS ContactPersons
	|WHERE
	|	ContactPersons.Owner = &Counterparty
	|	AND ContactPersons.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description,
	|	KindCI";
	
	Query.SetParameter("Counterparty", Ref);
	
	SelectionCP = Query.Execute().Select();
	While SelectionCP.Next() Do
		
		If RowsArray.Count() > 0 Then
			RowsArray.Add(Chars.LF);
		EndIf;
		RowsArray.Add(SelectionCP.Description);
		
		SelectionCI = SelectionCP.ContactInformation.Select();
		While SelectionCI.Next() Do
			If IsBlankString(SelectionCI.Presentation) Then
				Continue;
			EndIf;
			RowsArray.Add(SelectionCI.Presentation);
		EndDo;
		
	EndDo;
	
	If Not IsBlankString(Comment) Then
		RowsArray.Add(Comment);
	EndIf;
	
	If ValueIsFilled(Responsible) Then
		RowsArray.Add(Common.ObjectAttributeValue(Responsible, "Description"));
	EndIf;
	
	BasicInformation = StrConcat(RowsArray, Chars.LF);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	If NOT ValueIsFilled(SettlementsCurrency) Then
		SettlementsCurrency = DriveReUse.GetFunctionalCurrency();
	EndIf;
	
	If GetFunctionalOption("UseVAT") Then
		VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
	EndIf;
	
	If NOT ValueIsFilled(CashFlowItem) Then
		
		If Supplier AND NOT Customer Then
			CashFlowItem = Catalogs.CashFlowItems.PaymentToVendor;
		ElsIf OtherRelationship AND NOT Customer AND NOT Supplier Then
			CashFlowItem = Catalogs.CashFlowItems.Other;
		Else
			CashFlowItem = Catalogs.CashFlowItems.PaymentFromCustomers;
		EndIf;
		
	EndIf;
	
	If GetFunctionalOption("UsePurchaseOrderApproval") Then
		
		PurchaseOrdersApprovalType = Constants.PurchaseOrdersApprovalType.Get();
		If PurchaseOrdersApprovalType = Enums.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty Then
			
			LimitWithoutApproval = Constants.LimitWithoutPurchaseOrderApproval.Get();
			ApprovePurchaseOrders = LimitWithoutApproval > 0;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure checks the TIN correctness and fixes the counterparty duplicate existence
//
Procedure RegisterCounterpartyDuplicates()
	
	If IsFolder Then
		Return;
	EndIf;
	
	NeedToCheck = IsNew();
	
	IsLegalEntity = LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
	
	TINModified = NeedToCheck;
	
	If Not NeedToCheck Then
		
		PreviousValueStructure = Common.ObjectAttributesValues(Ref, 
																  "TIN,
																  |LegalEntityIndividual");
																			  
		If Not PreviousValueStructure.TIN = TIN 
			Or Not PreviousValueStructure.LegalEntityIndividual = LegalEntityIndividual Then
			
			NeedToCheck = True; 
			
		EndIf;
		
		TINModified = Not PreviousValueStructure.TIN = TIN;
		
		WasLegalEntity = PreviousValueStructure.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
		
		If NeedToCheck Then
			
			If Not PreviousValueStructure.TIN = TIN Then
			
				Block = New DataLock;
				
				If Not PreviousValueStructure.TIN = TIN Then
			
					LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicates");
					LockItemStillTIN.SetValue("TIN", PreviousValueStructure.TIN);
					LockItemStillTIN.Mode = DataLockMode.Exclusive;
					
				EndIf;
				
				Block.Lock();
				
			EndIf;
			
			PreviousDuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(PreviousValueStructure.TIN), Ref);
		Else
			PreviousDuplicateArray = New Array;
		EndIf;
		
	Else
		
		PreviousDuplicateArray = New Array;
		
	EndIf;
	
	If NeedToCheck Then
		
		If TINModified Then
			
			Block = New DataLock;
			LockItemByTIN = Block.Add("InformationRegister.CounterpartyDuplicates");
			LockItemByTIN.SetValue("TIN", TIN);
			LockItemByTIN.Mode = DataLockMode.Exclusive;
			
			Block.Lock();
			
			DuplicateArray = Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTIN(TrimAll(TIN), Ref, True);
																								
			If DuplicateArray.Count() > 0 Then
				
				// For new item reference will be available only OnWrite, there also we will write.
				AdditionalProperties.NeedToWriteInRegisterOnWrite = True;
				
				For Each ArrayElement In DuplicateArray Do
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(ArrayElement, TIN, False);
				EndDo;
				
			EndIf;
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, True);
				
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, True);
				EndIf;
				
			EndIf;
			
		Else
			
			If PreviousDuplicateArray.Count() > 0 Then
				
				Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(Ref, PreviousValueStructure.TIN, True);
			
				If PreviousDuplicateArray.Count() = 1 Then
					Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(PreviousDuplicateArray[0], PreviousValueStructure.TIN, True);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure clears the register CounterpartyDuplicateExist
//
Procedure DeleteDuplicateRegistrationBeforeDelete()
	
	DuplicateArray = Catalogs.Counterparties.HasRecordsInDuplicatesRegister(TrimAll(TIN), Ref);
	
	If DuplicateArray.Count() = 1 Then
		
		Block = New DataLock;
		LockItemStillTIN = Block.Add("InformationRegister.CounterpartyDuplicates");
		LockItemStillTIN.SetValue("TIN", TIN);
		LockItemStillTIN.Mode = DataLockMode.Exclusive;
		
		Block.Lock();
		
		Catalogs.Counterparties.ExecuteRegisterRecordsOnRegisterTakes(DuplicateArray[0], TIN, True);
		
	EndIf;
	
EndProcedure

// The procedure checks the consistency of the data in IB
//
// Parameters:
//  Cancel	 - 	Boolean - Establish True in the case of inconsistent data
//
Procedure CheckChangePossibility(Cancel)
	
	PreviousValues = Common.ObjectAttributesValues(Ref,
		"DoOperationsByContracts,DoOperationsByOrders");
		
	If DoOperationsByOrders <> PreviousValues.DoOperationsByOrders Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	AccountsReceivable.Counterparty
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|WHERE
		|	AccountsReceivable.Counterparty = &Counterparty
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	AccountsPayable.Counterparty
		|FROM
		|	AccumulationRegister.AccountsPayable AS AccountsPayable
		|WHERE
		|	AccountsPayable.Counterparty = &Counterparty";
		
		Query.SetParameter("Counterparty", Ref);
		
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If Not QueryResult.IsEmpty() Then
			MessageText = NStr("en = 'There are entries in the infobase containing existing billing details. Cannot change billing details.'; ru = 'В базе присутствуют движения по существующим реквизитам. Изменение реквизитов запрещено.';pl = 'W bazie informacyjnej istnieją zapisy, zawierające istniejące dane rozliczeniowe. Nie można zmienić szczegółów płatności.';es_ES = 'Hay entradas en la infobase que contienen los detalles de facturación existentes. No se pueden cambiar los detalles de facturación.';es_CO = 'Hay entradas en la infobase que contienen los detalles de facturación existentes. No se pueden cambiar los detalles de facturación.';tr = 'Bilgi tabanında var olan faturalama ayrıntılarını içeren girdiler mevcuttur. Faturalama ayrıntıları değiştirilemez.';it = 'Ci sono inserimenti nel database contenenti dettagli contabili esistenti. Impossibile modificare i dettagli contabili.';de = 'In der Infobase gibt es Einträge mit vorhandenen Abrechnungsdetails. Die Abrechnungsdetails können nicht geändert werden.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
		EndIf;
		
	EndIf;
	
	If NOT DoOperationsByContracts AND DoOperationsByContracts <> PreviousValues.DoOperationsByContracts Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	CounterpartyContracts.Company AS Company,
		|	COUNT(CounterpartyContracts.Ref) AS RefCount
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|WHERE
		|	CounterpartyContracts.Owner = &Counterparty
		|
		|GROUP BY
		|	CounterpartyContracts.Company
		|
		|HAVING
		|	COUNT(CounterpartyContracts.Ref) > 1";
		
		Query.SetParameter("Counterparty", Ref);
		
		SetPrivilegedMode(True);
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			MessageText = NStr("en = 'There are more than one contracts for a company. Cannot change desired contract details.'; ru = 'Для компании существует несколько договоров. Изменение требуемых реквизитов договора запрещено.';pl = 'Istnieje więcej, niż jeden kontrakt dla firmy. Nie można zmienić żądanych szczegółów umowy.';es_ES = 'Para una empresa hay más de un contrato. No se pueden modificar los detalles del contrato deseado.';es_CO = 'Para una empresa hay más de un contrato. No se pueden modificar los detalles del contrato deseado.';tr = 'Bir şirket için birden fazla sözleşme mevcuttur. İstenen sözleşme ayrıntıları değiştirilemez.';it = 'C''è più di un contratto per un''azienda. Impossibile modificare i dettagli di contratto desiderati.';de = 'Es gibt mehr als einen Vertrag für eine Firma. Die gewünschten Vertragsdetails können nicht geändert werden.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure coordinates the state some attributes of the object depending on the other
//
Procedure BringDataToConsistentState()
	
	If LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		
		LegalForm = Catalogs.LegalForms.EmptyRef();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf