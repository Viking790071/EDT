#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Company) Then
			SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
			If ValueIsFilled(SettingValue) Then
				Object.Company = SettingValue;
			Else
				Object.Company = Catalogs.Companies.MainCompany;
			EndIf;
		EndIf;
		
		UsePeripherals = GetFunctionalOption("UsePeripherals");
		
		If Object.TypeOfPOS = Enums.TypesOfPOS.OnlinePayments Or Not UsePeripherals Then
			Object.UseWithoutEquipmentConnection = True;
		EndIf;
		
		Object.ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
		
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		OnReadOnCreateAtServer(Object);
	EndIf;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.PaymentProcessor);
	
	SetBankAccountChoiceParameters(False);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	If IsBlankString(Object.Description) Then
		Object.Description = MakeAutoDescription();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleAndEnabled();
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "GLAccountChangedPOSTerminals" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	ElsIf EventName = "Write_Counterparty" 
		And ValueIsFilled(Parameter)
		And Object.PaymentProcessor = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetVisibleAndEnabled();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnReadOnCreateAtServer(CurrentObject);
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TypeOfPOSOnChange(Item)
	
	If TypeOfPOS <> Object.TypeOfPOS Then
		
		If Object.TypeOfPOS = PredefinedValue("Enum.TypesOfPOS.OnlinePayments") Then
			TypeOfPOSOnChangeServer();
		EndIf;
		
		SetVisibleAndEnabled();
		
		TypeOfPOS = Object.TypeOfPOS;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If Company <> Object.Company Then
		
		If Object.TypeOfPOS = PredefinedValue("Enum.TypesOfPOS.OnlinePayments") Then
			CompanyOnChangeAtServer();
		EndIf;
		Company = Object.Company;
		
	Else
		
		Object.PettyCash = PettyCash;
		Object.PaymentProcessorContract = PaymentProcessorContract;
		Object.BankAccount = BankAccount;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseWithoutEquipmentConnectionOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure PettyCashOnChange(Item)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure PaymentProcessorOnChange(Item)
	
	If PaymentProcessor <> Object.PaymentProcessor Then
		
		PaymentProcessorOnChangeAtServer();
		SetVisibleAndEnabled();
		PaymentProcessor = Object.PaymentProcessor;
		
	Else
		
		Object.PaymentProcessorContract = PaymentProcessorContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentProcessorContractOnChange(Item)
	
	PaymentProcessorContractOnChangeAtServer();
	PaymentProcessorContract = Object.PaymentProcessorContract;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
	
EndProcedure

#EndRegion

#Region PaymentCardKindsFormTableItemsEventHandlers

&AtClient
Procedure PaymentCardKindsFeePercentOnChange(Item)
	
	CurRow = Items.PaymentCardKinds.CurrentData;
	
	If CurRow.FeePercent > 100 Then
		CurRow.FeePercent = 100;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetBankAccountChoiceParameters(ClearNonValidValue = True)
	
	If ValueIsFilled(Object.PaymentProcessorContract) Then
		ContractCurrency = Common.ObjectAttributeValue(Object.PaymentProcessorContract, "SettlementsCurrency");
	Else
		ContractCurrency = Catalogs.Currencies.EmptyRef();
	EndIf;
	
	If ClearNonValidValue And ValueIsFilled(Object.BankAccount) Then
		BankAccountCurrency = Common.ObjectAttributeValue(Object.BankAccount, "CashCurrency");
		If ContractCurrency <> BankAccountCurrency Then
			Object.BankAccount = "";
			BankAccount = "";
		EndIf;
	EndIf;
	
	CP_Array = New Array;
	CP_Array.Add(New ChoiceParameter("Filter.CashCurrency", ContractCurrency));
	Items.BankAccount.ChoiceParameters = New FixedArray(CP_Array);
	
EndProcedure

&AtServer
Procedure TypeOfPOSOnChangeServer()
	
	SetDefaultPaymentProcessorContract();
	SetBankAccountChoiceParameters();
	
EndProcedure

&AtServer
Procedure PaymentProcessorContractOnChangeAtServer()
	
	SetBankAccountChoiceParameters();
	
EndProcedure

&AtServer
Procedure PaymentProcessorOnChangeAtServer()
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.PaymentProcessor);
	SetDefaultPaymentProcessorContract();
	SetBankAccountChoiceParameters();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	SetDefaultPaymentProcessorContract();
	SetBankAccountChoiceParameters();
	
EndProcedure

&AtServer
Function SetDefaultPaymentProcessorContract()
	
	ContractTypes = New ValueList;
	ContractTypes.Add(Enums.ContractType.PaymentProcessor);
	
	DefaultContract = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(Object.PaymentProcessor,
		Object.Company, ContractTypes);
	
	Object.PaymentProcessorContract = DefaultContract;
	PaymentProcessorContract = DefaultContract;
	
EndFunction

&AtServer
Procedure OnReadOnCreateAtServer(Object)
	
	TypeOfPOS = Object.TypeOfPOS;
	Company = Object.Company;
	PettyCash = Object.PettyCash;
	PaymentProcessor = Object.PaymentProcessor;
	PaymentProcessorContract = Object.PaymentProcessorContract;
	BankAccount = Object.BankAccount;
	
EndProcedure

&AtClient
Procedure SetVisibleAndEnabled()
	
	IsOnlinePayment = (Object.TypeOfPOS = PredefinedValue("Enum.TypesOfPOS.OnlinePayments"));
	
	Items.PettyCash.Visible = Not IsOnlinePayment;
	Items.GroupPeripherals.Visible = Not IsOnlinePayment;
	
	Items.PaymentProcessor.Visible = IsOnlinePayment;
	Items.PaymentProcessorContract.Visible = IsOnlinePayment;
	Items.BankAccount.Visible = IsOnlinePayment;
	Items.WithholdFeeOnPayout.Visible = IsOnlinePayment;
	Items.BusinessLine.Visible = IsOnlinePayment;
	Items.Department.Visible = IsOnlinePayment;
	Items.Project.Visible = IsOnlinePayment;
	Items.PaymentCardKindsFeePercent.Visible = IsOnlinePayment;
	Items.PaymentCardKindsFeeFixedPart.Visible = IsOnlinePayment;
	
	If Object.UseWithoutEquipmentConnection And Not UsePeripherals Then
		Items.UseWithoutEquipmentConnection.Enabled = False;
	EndIf;
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
	Items.PaymentProcessorContract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val Counterparty)
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, Counterparty, "DoOperationsByContracts");
	
EndProcedure

&AtClient
Function MakeAutoDescription()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = NStr("en = 'POS terminal (%1)'; ru = 'Эквайринговый терминал (%1)';pl = 'Terminal POS (%1)';es_ES = 'Terminal TPV (%1)';es_CO = 'Terminal TPV (%1)';tr = 'POS terminali (%1)';it = 'Terminale POS (%1)';de = 'POS-Terminal (%1)'");
	
	If Object.TypeOfPOS = PredefinedValue("Enum.TypesOfPOS.PhysicalPOS") Then
		DescriptionParameter = Object.PettyCash;
	ElsIf Object.TypeOfPOS = PredefinedValue("Enum.TypesOfPOS.OnlinePayments") Then
		DescriptionParameter = Object.PaymentProcessor;
	Else
		DescriptionParameter = "";
	EndIf;
	
	DescriptionString = StringFunctionsClientServer.SubstituteParametersToString(DescriptionString, DescriptionParameter);
	DescriptionString = Left(DescriptionString, 100);
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction

#EndRegion
