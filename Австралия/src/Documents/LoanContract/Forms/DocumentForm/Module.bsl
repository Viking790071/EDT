
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.SettlementsCurrency, Object.Company);
	Rate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate);
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition);

	LoanKindOnCreation			= Object.LoanKind;
	CounterpartyWhenCreating	= Object.Counterparty;
	EmployeeWhenCreating		= Object.Employee;
	CompanyWhenCreating			= Object.Company;
	SettlementsCurrency			= Object.SettlementsCurrency;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		DueDate = 1;
	Else
		DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, 
			?(Object.FirstRepayment = '00010101', 
				Object.Issued, 
				AddMonth(Object.FirstRepayment, -1)));
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Object.LoanKind = Enums.LoanContractTypes.Borrowed;

		DueDate = 1;
		
		Object.Issued				= CurrentSessionDate();
		Object.Maturity				= AddMonth(BegOfDay(Object.Issued) - 1, DueDate);
		Object.FirstRepayment		= AddMonth(Object.Issued, 1);
		
		SetDefaultValuesForLoanKind();
		
		SetDefaultValuesForIncomeAndExpenseItems();
		
	Else
		DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, 
			?(Object.FirstRepayment = '00010101',
				Object.Issued, 
				AddMonth(Object.FirstRepayment, -1)));
	EndIf;
	
	// Predefined values
	RepaymentOptionMonthly		= Enums.OptionsOfLoanRepaymentByEmployee.MonthlyRepayment;
	LoanKindLoanContract		= Enums.LoanContractTypes.EmployeeLoanAgreement;
	LoanKindCounterpartyLoan	= Enums.LoanContractTypes.CounterpartyLoanAgreement;
	NoCommissionType			= Enums.LoanCommissionTypes.No;
	CommissionTypeBySchedule	= Enums.LoanCommissionTypes.CustomSchedule;
	// End Predefined values
	
	CommissionType = Object.CommissionType;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy();
	FunctionalOptionCashMethodOfIncomeAndExpenseAccounting = AccountingPolicy.CashMethodOfAccounting;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");

	SetItemVisibilityDependingOnLoanKind();
	SetAccountingParameterVisibilityOnServer();
	
	CurrentSystemUser = UsersClientServer.CurrentUser();
	
	If UseDefaultTypeOfAccounting Then
		
		If Not Object.Ref.IsEmpty() Then
			If ThereRecordsUnderTheContract(Object.Ref) Then
				Items.GroupGLAccountsColumns.Tooltip = 
					NStr("en = 'It is not recommended to change GL accounts after subsidary documents have been posted.'; ru = 'В базе есть движения по этому договору. Изменение счетов учета не рекомендуется.';pl = 'Nie zaleca się zmiany kont księgi głównej po zaksięgowaniu dokumentów subsydiarnych.';es_ES = 'Se recomienda cambiar las cuentas del libro mayor después de que los documentos subsidiarios se hayan enviado.';es_CO = 'Se recomienda cambiar las cuentas del libro mayor después de que los documentos subsidiarios se hayan enviado.';tr = 'Giden dokümanların gönderilmesinden sonra Muhasebe hesaplarının değiştirilmesi tavsiye edilmez.';it = 'Non è consigliabile cambiare i conti mastro dopo che i documenti delle controllate sono stati pubblicati';de = 'Es wird nicht empfohlen, die Hauptbuch-Konten zu ändern, nachdem die Nebendokumente gebucht wurden.'");
			EndIf;
		EndIf;
		
	EndIf;
		
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	SetVisibilityOfItems();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Object.Ref.IsEmpty() Then
		CheckChangePossibility(Cancel);
		
		If Not Cancel Then
			
			LoanKindOnCreation			= Object.LoanKind;
			CounterpartyWhenCreating	= Object.Counterparty;
			EmployeeWhenCreating		= Object.Employee;
			CompanyWhenCreating			= Object.Company;
			
		EndIf;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.PaymentsAndAccrualsSchedule.Count() = 0
		And Not Object.Total = 0 Then
		
		If Not ValueIsFilled(Object.PaymentTerms) Then
			Object.PaymentTerms		= PredefinedValue("Enum.LoanRepaymentTerms.AnnuityPayments");
			PopulatePaymentAmount();
		EndIf;
		
		PopulatePaymentsAndAccrualsScheduleOnServer();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CommissionAmountOnChange(Item)
	PopulatePaymentAmount();
EndProcedure

&AtClient
Procedure CommissionTypeOnChange(Item)
	
	ConfigureItemsByCommissionTypeAndLoanKind();
	SetItemVisibilityDependingOnLoanKind();
	ClearAttributesDependingOnCommissionType();
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure AnnualInterestRateOnChange(Item)
	
	PopulatePaymentAmount();
	SetDeductionVisibility();
	
EndProcedure

&AtClient
Procedure RepaymentOptionOnCange(Item)
	
	RepaymentOptionWhenChangingOnServer();
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure DocumentAmountOnChange(Item)	
	PopulatePaymentAmount();	
EndProcedure

&AtClient
Procedure IssuedOnChange(Item)
	
	PopulateEndDateByDueDate(Object.Issued);
	
	Object.FirstRepayment = AddMonth(Object.Issued, 1);
	
	If EndOfDay(Object.Issued) = EndOfMonth(Object.Issued) Then
		Object.FirstRepayment = EndOfMonth(Object.FirstRepayment);
	EndIf;
	
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure DueDateOnChange(Item)
	
	If Object.FirstRepayment = '00010101' Then
		If EndOfDay(Object.Issued) = EndOfMonth(Object.Issued) Then
			Object.FirstRepayment = EndOfMonth(AddMonth(Object.Issued, 1));
		Else
			Object.FirstRepayment = AddMonth(Object.Issued, 1);
		EndIf;
	EndIf;
	
	If EndOfDay(Object.FirstRepayment) = EndOfMonth(Object.FirstRepayment) Then
		StartDate = EndOfMonth(AddMonth(Object.FirstRepayment, -1));
	Else
		StartDate = AddMonth(Object.FirstRepayment, -1);
	EndIf;
	
	PopulateEndDateByDueDate(StartDate);
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	PopulateDueDateByEndDate(Object.Issued);
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure FirstRepaymentOnChange(Item)
	
	If Object.FirstRepayment = '00010101' Then
		Object.FirstRepayment = AddMonth(Object.Issued, 1);
	EndIf;
	
	PopulateEndDateByDueDate(AddMonth(Object.FirstRepayment, -1));
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure LoanKindOnChange(Item)
	LoanKindWhenChangingOnServer();
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)	
	GLAccountWhenChangingOnServer();	
EndProcedure

&AtClient
Procedure PaymentTermsOnChange(Item)	
	
	PopulatePaymentAmount();
	SetVisibilityOfItems();
	
EndProcedure

&AtClient
Procedure DaysInYear360OnChange(Item)	
	PopulatePaymentAmount();	
EndProcedure

&AtClient
Procedure CostAccountCommissionOnChange(Item)
	
	CommissionGLAccountWhenChangingOnServer();
	
	Structure = New Structure("
	|Object,
	|CommissionGLAccount,
	|InterestIncomeItem,
	|InterestExpenseItem,
	|CommissionIncomeItem,
	|CommissionExpenseItem,
	|LoanKind,
	|Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

&AtClient
Procedure CostAccountOnChange(Item)
	
	Structure = New Structure("
	|Object,
	|CostAccount,
	|InterestIncomeItem,
	|InterestExpenseItem,
	|CommissionIncomeItem,
	|CommissionExpenseItem,
	|LoanKind,
	|Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure ChargeFromSalaryOnChange(Item)
	
	SetDeductionVisibility();
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

&AtClient
Procedure PagesIssueAndRepayLoanCreditWhenChangingPage(Item, CurrentPage)
	
	If Not IsBlankString(Object.Comment) AND Items.AdvancedPage.Picture = New Picture Then
		AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure InterestExpenseItemOnChange(Item)
	SetAccountingParameterVisibilityOnServer();
EndProcedure

&AtClient
Procedure CommissionExpenseItemOnChange(Item)
	SetAccountingParameterVisibilityOnServer();
EndProcedure

#EndRegion

#Region HandlersOfEventsItemsTableFormPaymentsAndAccrualsSchedule

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	SetVisibilityOfItems();
	
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsScheduleInterestAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsScheduleCommissionAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsSchedulePrincipalDebtAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PopulatePaymentsAndAccrualsSchedule(Command)
	
	If Object.Total = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Amount is not populated'; ru = 'Сумма не заполнена';pl = 'Nie wypełniono pola ""Kwota""';es_ES = 'Importe no está poblado';es_CO = 'Importe no está poblado';tr = 'Tutar doldurulmadı';it = 'L''importo non è compilato';de = 'Der Betrag ist nicht ausgefüllt'"),,
			"Object.Total");		
		Return;
	EndIf;
	
	PopulatePaymentsAndAccrualsScheduleOnServer();
	
EndProcedure

&AtClient
Procedure CreatePaymentReminders(Command)
	
	If Object.Ref.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Please save the loan contract.'; ru = 'Сохраните договор займа.';pl = 'Zapisz umowę pożyczki.';es_ES = 'Guarde el contrato de préstamo.';es_CO = 'Guarde el contrato de préstamo.';tr = 'Lütfen, kredi sözleşmesini kaydedin.';it = 'Salvare il contratto di prestito.';de = 'Bitte speichern Sie den Darlehensvertrag.'"));
		Return;
	EndIf;
	
	If Object.PaymentsAndAccrualsSchedule.Count() = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Installments required.'; ru = 'Укажите платежи.';pl = 'Wymagane są raty.';es_ES = 'Se requieren plazos.';es_CO = 'Se requieren plazos.';tr = 'Taksitler gerekli.';it = 'Richieste rate.';de = 'Raten ist ein Pflichtfeld.'"));
		Return;
	EndIf;
	
	AddressPaymentsAndAccrualsScheduleInStorage = PlacePaymentsAndAccrualsScheduleToStorage();
	FilterParameters = New Structure("AddressPaymentsAndAccrualsScheduleInStorage,
		|Company,
		|Recorder,
		|DocumentFormID,
		|CounterpartyBank",
		AddressPaymentsAndAccrualsScheduleInStorage,
		Object.Company,
		Object.Ref,
		UUID,
		Object.Counterparty);
		
	OpenForm("Document.LoanContract.Form.ReminderCreationForm", 
		FilterParameters,
		ThisForm,,,,
		Undefined);	
		
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure LoanKindWhenChangingOnServer()
	
	SetDefaultValuesForLoanKind();
	ClearAttributesNotRelatedToLoanKind();
	SetItemVisibilityDependingOnLoanKind();
	
EndProcedure

&AtServer
Procedure GLAccountWhenChangingOnServer()
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtServer
Procedure CommissionGLAccountWhenChangingOnServer()
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtClient
Procedure ClearAttributesDependingOnCommissionType()

	PreviousCommissionType = CommissionType;
	CommissionType = Object.CommissionType;
	
	If PreviousCommissionType <> CommissionType Then
		If CommissionType = CommissionTypeBySchedule OR CommissionType = NoCommissionType Then
			
			Object.Commission = 0;
			
			If CommissionType = NoCommissionType Then
				For Each CurrentScheduleLine In Object.PaymentsAndAccrualsSchedule Do
				
					CurrentScheduleLine.Commission = 0;
					RecalculatePaymentAmount(CurrentScheduleLine);
				
				EndDo;
			EndIf;		
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure RepaymentOptionWhenChangingOnServer()

	PaymentAvailability = (Object.RepaymentOption = RepaymentOptionMonthly);
	
	Items.PaymentTerms.Enabled = PaymentAvailability;
	Items.PaymentsAndAccrualsSchedulePopulatePaymentsAndAccrualsSchedule.Enabled = PaymentAvailability;
	
EndProcedure

&AtServer
Procedure CheckChangePossibility(Cancel)
	
	If LoanKindOnCreation = Object.LoanKind 
		AND CounterpartyWhenCreating = Object.Counterparty 
		AND	EmployeeWhenCreating = Object.Employee 
		AND	CompanyWhenCreating = Object.Company Then
			Return;
	EndIf;
	
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED TOP 1
	|	LoanSettlements.Recorder
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	(LoanSettlements.LoanKind <> &LoanKind
	|			OR (LoanSettlements.Counterparty <> &Counterparty AND &CheckCounterparty)
	|			OR (LoanSettlements.Counterparty <> &Employee AND &CheckEmployee)
	|			OR LoanSettlements.Company <> &Company)
	|	AND LoanSettlements.LoanContract = &CurrentContract";
	
	Query.Text = QueryText;
	Query.SetParameter("CurrentContract",	Object.Ref);
	Query.SetParameter("LoanKind",			Object.LoanKind);
	Query.SetParameter("Counterparty",		Object.Counterparty);
	Query.SetParameter("Employee",			Object.Employee);
	Query.SetParameter("Company",			DriveServer.GetCompany(Object.Company));
	Query.SetParameter("CheckCounterparty",	Object.LoanKind = Enums.LoanContractTypes.Borrowed 
												OR Object.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement);
	Query.SetParameter("CheckEmployee",		Object.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'There are documents in the base where the current contract is selected. 
		                   |Cannot change company, contract kind, counterparty bank, and employee. 
		                   |To view a linked document list, use the More - Linked documents command.'; 
		                   |ru = 'В базе присутствуют документы, в которых выбран текущий договор. 
		                   |Изменение организации, вида договора, банка-контрагента и сотрудника запрещено. 
		                   |Для просмотра списка связанных документах можно использовать команду ""Еще - Связанные документы"".';
		                   |pl = 'W bazie znajdują się dokumenty, w których wybrano bieżącą umowę. 
		                   |Zmiana organizacji, rodzaju umowy, banku kontrahenta i pracownika nie jest możliwa. 
		                   |Aby wyświetlić listę powiązanych dokumentów, należy użyć polecenia Dodatkowe - Dokumenty powiązane.';
		                   |es_ES = 'Hay documentos en la base donde el contrato actual está seleccionado. 
		                   |No se puede cambiar la empresa, el tipo de contrato, el banco de la contraparte y el empleado. 
		                   |Para ver una lista de documentos vinculados, utilizar el comando Más - Documentos vinculados.';
		                   |es_CO = 'Hay documentos en la base donde el contrato actual está seleccionado. 
		                   |No se puede cambiar la empresa, el tipo de contrato, el banco de la contraparte y el empleado. 
		                   |Para ver una lista de documentos vinculados, utilizar el comando Más - Documentos vinculados.';
		                   |tr = 'Mevcut sözleşmenin seçildiği yerde belgeler var. 
		                   |İş yeri, sözleşme türü, cari hesap bankası ve çalışan değiştirilemez. 
		                   |Bağlantılı bir belge listesini görüntülemek için Daha Fazla-Bağlantılı belgeler komutunu kullanın.';
		                   |it = 'Ci sono documenti nella base dove l''attuale contratto è selezionato. 
		                   |Non è possibile cambiare società, il contratto tipo, di controparte della banca e dei dipendenti. 
		                   |per visualizzare un elenco documenti collegati, utilizzare il comando Più Documenti Collegati.';
		                   |de = 'In der Basis befinden sich Dokumente, in denen der aktuelle Vertrag ausgewählt wird.
		                   |Kann Firma, Vertragsart, Bank des Geschäftspartners und Mitarbeiter nicht ändern.
		                   |Um eine Liste verknüpfter Dokumente anzuzeigen, verwenden Sie den Befehl Weitere - Verknüpfte Dokumente.'");
		DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , , Cancel);
	EndIf;
	
EndProcedure

// Function checks whether GL account can be changed.
//
&AtServerNoContext
Function ThereRecordsUnderTheContract(Ref)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	LoanSettlements.Period,
	|	LoanSettlements.Recorder,
	|	LoanSettlements.LineNumber,
	|	LoanSettlements.Active,
	|	LoanSettlements.RecordType,
	|	LoanSettlements.LoanKind,
	|	LoanSettlements.Counterparty,
	|	LoanSettlements.Company,
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.PrincipalDebt,
	|	LoanSettlements.PrincipalDebtCur,
	|	LoanSettlements.Interest,
	|	LoanSettlements.InterestCur,
	|	LoanSettlements.Commission,
	|	LoanSettlements.CommissionCur,
	|	LoanSettlements.DeductedFromSalary,
	|	LoanSettlements.PostingContent,
	|	LoanSettlements.StructuralUnit
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.LoanContract = &Ref");
	
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure sets an end date by start date and number of months.
//
&AtClient
Procedure PopulateEndDateByDueDate(StartDate) Export
	
	If DueDate > 0 Then
		Object.Maturity = AddMonth(BegOfDay(StartDate) - 1, DueDate);
		
		If EndOfDay(StartDate) = EndOfMonth(StartDate) Then
			Object.Maturity = EndOfMonth(Object.Maturity);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PopulateDueDateByEndDate(StartDate) Export
	
	DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, StartDate);
	
EndProcedure

// Procedure fills in the payment amount depending on the payment kind and repayment option.
//
&AtClient
Procedure PopulatePaymentAmount()
	
	If Object.RepaymentOption = RepaymentOptionMonthly Then
		
		If Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.AnnuityPayments") Then
			Object.PaymentAmount = AnnuityPaymentAmount();
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments")
			OR Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyPrincipal") Then
			Object.PaymentAmount = Object.Total / DueDate;
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyInterest") Then
			Object.PaymentAmount = Object.Total * object.InterestRate * 0.01 / 12;
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.CustomSchedule") Then
			Object.PaymentAmount = Object.Total / DueDate;
		Else
			Object.PaymentAmount = 0;
		EndIf;
		
		If Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments") 
			AND Not Object.DaysInYear360 Then
			Object.DaysInYear360 = True;
		EndIf;
		
	Else
		
		AccumulatedInterest = 0;
		MonthNumber = 1;
	
		StartMonth = BegOfMonth(Object.Issued);
		EndMonth = BegOfMonth(Object.Maturity);
		
		CurrentMonth = StartMonth;
		While CurrentMonth <= EndMonth Do
		
			DaysPerYear = NumberOfDaysInYear(Year(CurrentMonth), Object.DaysInYear360);
			
			If CurrentMonth = BegOfMonth(Object.Issued) Then
				// During the first month, determine the number of days from the actual loan issue
				// date (as interest is accrued on the next day).
				If CurrentMonth = EndMonth Then
					DaysInMonth = Min(Day(EndOfMonth(CurrentMonth)), Day(Object.Maturity)) - Day(Object.Issued);
				Else
					DaysInMonth = Day(EndOfMonth(CurrentMonth)) - Day(Object.Issued);
				EndIf;
			Else
				If CurrentMonth = EndMonth Then
					DaysInMonth = Min(Day(EndOfMonth(CurrentMonth)), Day(Object.Maturity));
				Else
					DaysInMonth = Day(EndOfMonth(CurrentMonth));
				EndIf;
			EndIf;
			
			InterestAccrual = Object.Total * Object.InterestRate * 0.01 * DaysInMonth / DaysPerYear;
			
			CurrentMonth	= AddMonth(CurrentMonth, 1);
			MonthNumber		= MonthNumber + 1;
			
			AccumulatedInterest = AccumulatedInterest + InterestAccrual;
			
		EndDo;
		
		CommissionAmount = GetCommissionAmount(Object.Total);
		
		Object.PaymentAmount = Object.Total + AccumulatedInterest + CommissionAmount;
		Object.PaymentsAndAccrualsSchedule.Clear();
		
		RemainingDebt = Object.PaymentAmount;
		
		NewScheduleLine = Object.PaymentsAndAccrualsSchedule.Add();
		NewScheduleLine.PaymentDate		= Object.Maturity;
		NewScheduleLine.Principal		= Object.Total;
		NewScheduleLine.Interest		= AccumulatedInterest;
		NewScheduleLine.PaymentAmount	= Object.PaymentAmount;
		NewScheduleLine.Commission 		= CommissionAmount;
		
		LineLoanKind = ?(Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.EmployeeLoanAgreement"), 
		NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"),
		NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"));
		
		If Object.InterestRate <> 0 Then
			NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1% of total %2 amount repaid.'; ru = 'Процент суммы погашенного долга составляет %1% от суммы %2.';pl = 'spłacono %1% sumy %2.';es_ES = '%1% del importe %2 total pagado.';es_CO = '%1% del importe %2 total pagado.';tr = 'Toplam %2 tutarın %1%''si geri ödendi.';it = '%1% del totale %2 importo ripagato.';de = '%1% des Gesamt%2 betrags zurückgezahlt.'"),
			Format(Object.PaymentAmount / RemainingDebt * 100, "NFD=2; NZ=0"),
			LineLoanKind);
		Else
			NewScheduleLine.Comment = "";
		EndIf;
		
		RemainingDebt = RemainingDebt - Object.PaymentAmount;
		
		NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 Debt balance is %2 (%3).'; ru = '%1 Остаток долга равен %2 (%3).';pl = '%1 Saldo zadłużenia wynosi %2 (%3).';es_ES = '%1 Saldo de la deuda es %2 (%3).';es_CO = '%1 Saldo de la deuda es %2 (%3).';tr = '%1Borç bakiyesi %2(%3).';it = '%1 saldo del debito è %2 (%3).';de = '%1 Schuldenstand ist %2 (%3).'"),
		NewScheduleLine.Comment,
		Format(RemainingDebt, "NFD=2; NZ=0"),
		Object.SettlementsCurrency);
		
	EndIf;
	
EndProcedure

// Function determines a number of days in a month.
//
// Parameters:
//	Date - any month date
//
// Returns
//	- date, number of days
// in a month
&AtServerNoContext
Function NumberOfMonthDays(Date, DaysInYear360) Export
	
	If DaysInYear360 Then
		Return 30;
	Else
		Return Day(EndOfMonth(Date));
	EndIf;
	
EndFunction

// Function determines a number of days in a year.
//
//	Parameters:
// - Year - Number
&AtServerNoContext
Function NumberOfDaysInYear(Year, DaysInYear360) Export
	
	If DaysInYear360 Then
		Return 360;
	Else
		// If there are 29 days in February - then 366, otherwise 365.
		If Day(EndOfMonth(Date(Year, 2, 1))) = 29 Then
			Return 366;
		Else
			Return 365;
		EndIf;
	EndIf;
	
EndFunction

&AtServer
Function PlacePaymentsAndAccrualsScheduleToStorage()

	AddressInStorage = PutToTempStorage(Object.PaymentsAndAccrualsSchedule.Unload(), UUID);	
	Return AddressInStorage;

EndFunction

&AtClient
Procedure RecalculatePaymentAmount(CurrentData)	
	CurrentData.PaymentAmount = CurrentData.Principal + CurrentData.Interest + CurrentData.Commission;	
EndProcedure

&AtServer
Procedure RecalculatePaymentAmountOnServer(CurrentData)	
	CurrentData.PaymentAmount = CurrentData.Principal + CurrentData.Interest + CurrentData.Commission;	
EndProcedure

&AtServer
Procedure SetItemVisibilityDependingOnLoanKind()
	
	If Object.LoanKind = Enums.LoanContractTypes.Borrowed
		Or Object.LoanKind = LoanKindCounterpartyLoan Then
		
		IsCounterpartyLoan = (Object.LoanKind = LoanKindCounterpartyLoan);
		IsCommission = (Object.CommissionType <> Enums.LoanCommissionTypes.EmptyRef())
			And (Object.CommissionType <> Enums.LoanCommissionTypes.No);
		
		Items.Employee.Visible											= False;
		Items.Counterparty.Visible										= True;
		Items.ChargeFromSalary.Visible									= False;
		Items.LabelSeparatorInsteadOfCheckBoxChargeFromSalary.Visible	= True;
		
		If IsCounterpartyLoan Then
			Items.Counterparty.Title = NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
		EndIf;
		
		Items.CommissionExpenseItem.Visible = Not IsCounterpartyLoan And IsCommission;
		Items.InterestExpenseItem.Visible = Not IsCounterpartyLoan;
		Items.CommissionIncomeItem.Visible = IsCounterpartyLoan And IsCommission;
		Items.InterestIncomeItem.Visible = IsCounterpartyLoan;
		Items.CostAccountCommission.Visible = IsCommission;
		
	Else
		
		Items.Employee.Visible											= True;
		Items.Counterparty.Visible 										= False;
		Items.ChargeFromSalary.Visible									= True;
		Items.LabelSeparatorInsteadOfCheckBoxChargeFromSalary.Visible 	= False;
		
		Items.CommissionExpenseItem.Visible = False;
		Items.InterestExpenseItem.Visible = False;
		Items.CommissionIncomeItem.Visible = False;
		Items.InterestIncomeItem.Visible = True;
		Items.CostAccountCommission.Visible = False;
		
	EndIf;
	
	If Not UseDefaultTypeOfAccounting Then
		Items.Move(Items.StructuralUnit, Items.GroupExpensesAccountsRight);
		Items.Move(Items.Order, Items.GroupExpensesAccountsRight);
		Items.Move(Items.InterestExpenseItem, Items.GroupExpensesAccountsLeft);
		Items.Move(Items.InterestIncomeItem, Items.GroupExpensesAccountsLeft);
		Items.Move(Items.CommissionExpenseItem, Items.GroupExpensesAccountsLeft);
		Items.Move(Items.CommissionIncomeItem, Items.GroupExpensesAccountsLeft);
		Items.Move(Items.BusinessArea, Items.GroupExpensesAccountsLeft);
	EndIf;
	
	ConfigureItemsByCommissionTypeAndLoanKind();
	SetDeductionVisibility();
	SetTitleOrTooltipText();
	
EndProcedure

// Procedure sets visibility of items which are connected with the "DeductionPrincipalDebt" and "DeductionInterest" attributes.
&AtServer
Procedure SetDeductionVisibility()
	
	PrincipalDebtVisibility = GetFunctionalOption("UsePayrollSubsystem") 
		AND Object.ChargeFromSalary 
		AND Object.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement;
	InterestVisibility = PrincipalDebtVisibility AND Object.InterestRate <> 0;
	
	Items.DeductionPrincipalDebt.Visible	= PrincipalDebtVisibility;
	Items.DeductionInterest.Visible			= InterestVisibility;
	
EndProcedure

&AtServer
Procedure SetDefaultValuesForIncomeAndExpenseItems()
	
	Object.CommissionExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("LoanCommissionExpenses");
	Object.InterestExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestExpenses");
	Object.CommissionIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("LoanCommissionIncome");
	Object.InterestIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestIncome");
	
EndProcedure

// Procedure sets GL account values by default depending on the contract kind.
//
&AtServer
Procedure SetDefaultValuesForLoanKind()

	If Object.LoanKind = LoanKindLoanContract Then
		
		Object.GLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("LoansLentToEmployee");
		Object.InterestGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestReceivable");
		Object.CostAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestIncome");
		
		Object.InterestIncomeItem		= Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestIncome");
		
		Object.ChargeFromSalary			= GetFunctionalOption("UsePayrollSubsystem");
		
	ElsIf Object.LoanKind = LoanKindCounterpartyLoan Then
		
		Object.GLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("LoansLentToCounerparty");
		Object.InterestGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestReceivable");
		Object.CostAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestIncome");
		Object.CostAccountCommission	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CommissionIncomeOnLoansLent");
		Object.CommissionGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestReceivable");
		
		Object.InterestIncomeItem		= Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestIncome");
		Object.CommissionIncomeItem		= Catalogs.DefaultIncomeAndExpenseItems.GetItem("LoanCommissionIncome");
		
	Else
		
		Object.GLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("LoansBorrowed");
		Object.InterestGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestPayable");
		Object.CostAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestExpensesOnLoansBorrowed");
		Object.CostAccountCommission	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CommissionExpensesOnLoansBorrowed");
		Object.CommissionGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestPayable");
		
		Object.InterestIncomeItem		= Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestExpense");
		Object.CommissionIncomeItem		= Catalogs.DefaultIncomeAndExpenseItems.GetItem("LoanCommissionExpense");
		
	EndIf;
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtClient
Procedure SetVisibilityOfItems()
	
	Items.PaymentAmount.Visible = (Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.CustomSchedule"));
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentMethod()
	
	CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	If CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = True;
	ElsIf CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTitleOrTooltipText()
	
	// Title
	If Object.LoanKind = Enums.LoanContractTypes.Borrowed Then
		
		Items.GroupGLAccounts.Title			= NStr("en = 'Liability accounts'; ru = 'Счета пассивов';pl = 'Konta zobowiązania';es_ES = 'Cuentas de pasivo';es_CO = 'Cuentas de pasivo';tr = 'Borç hesapları';it = 'Conti di entrata';de = 'Verbindlichkeitskonten'");
		Items.CostAccount.Title				= NStr("en = 'Interest GL expenses'; ru = 'Счет учета расходов по процентам';pl = 'Konto księgowe rozchodów na prowizję';es_ES = 'Interés gastos del libro mayor';es_CO = 'Interés gastos del libro mayor';tr = 'Faiz hesabı giderler';it = 'Interessi spese libro mastro';de = 'Zins Hauptbuch-Ausgaben'");
		Items.CostAccountCommission.Title	= NStr("en = 'Commission GL expenses'; ru = 'Счет учета расходов по комиссии';pl = 'Konto księgowe rozchodów na prowizję';es_ES = 'Comisión gastos del libro mayor';es_CO = 'Comisión gastos del libro mayor';tr = 'Komisyon hesabı giderler';it = 'Commissione spese libro mastro';de = 'Provisionszahlung Hauptbuch-Ausgaben'");
		
		If UseDefaultTypeOfAccounting Then
			TitleExpensesAccounts = NStr("en = 'Expenses accounts'; ru = 'Счета расходов';pl = 'Konta rozchodów';es_ES = 'Cuentas de gastos';es_CO = 'Cuentas de gastos';tr = 'Gider hesapları';it = 'Conti di uscita';de = 'Ausgabenkonten'");
		Else
			TitleExpensesAccounts = NStr("en = 'Expenses items'; ru = 'Статьи расходов';pl = 'Pozycje rozchodów';es_ES = 'Artículos de gastos';es_CO = 'Artículos de gastos';tr = 'Gider kalemleri';it = 'Voci di uscita';de = 'Ausgabenposten'");
		EndIf;

	Else
		
		Items.GroupGLAccounts.Title			= NStr("en = 'Assets accounts'; ru = 'Счета активов';pl = 'Konta aktyw';es_ES = 'Cuentas de activos';es_CO = 'Cuentas de activos';tr = 'Kıymetler hesabı';it = 'Conti delle immobilizzazioni';de = 'Aktiva-Konten'");
		Items.CostAccount.Title				= NStr("en = 'Interest GL income'; ru = 'Счет учета доходов по процентам';pl = 'Konto księgowe dochodów z odsetek';es_ES = 'Interés ingresos del libro mayor';es_CO = 'Interés ingresos del libro mayor';tr = 'Faiz hesabı gelir';it = 'Interessi entrate libro mastro';de = 'Zins Hauptbuch-Einnahme'");
		Items.CostAccountCommission.Title	= NStr("en = 'Commission GL income'; ru = 'Счет учета доходов по комиссии';pl = 'Konto księgowe dochodów z prowizji';es_ES = 'Comisión ingresos del libro mayor';es_CO = 'Comisión ingresos del libro mayor';tr = 'Komisyon hesabı gelir';it = 'Commissione entrate libro mastro';de = 'Provisionszahlung Hauptbuch-Einnahme'");
		
		
		If UseDefaultTypeOfAccounting Then
			TitleExpensesAccounts = NStr("en = 'Income accounts'; ru = 'Счета доходов';pl = 'Konta dochodów';es_ES = 'Cuentas de ingresos';es_CO = 'Cuentas de ingresos';tr = 'Gelir hesapları';it = 'Conti di entrata';de = 'Einnahmekonten'");
		Else
			TitleExpensesAccounts = NStr("en = 'Income items'; ru = 'Статьи доходов';pl = 'Pozycje dochodów';es_ES = 'Artículos de ingresos';es_CO = 'Artículos de ingresos';tr = 'Gelir kalemleri';it = 'Voci di entrata';de = 'Einnahmeposten'");
		EndIf;

	EndIf;
	
	Items.GroupExpensesAccounts.Title = TitleExpensesAccounts;
	
	// ToolTip
	If Object.LoanKind = Enums.LoanContractTypes.Borrowed Then

		Items.InterestExpenseItem.ToolTip	= NStr("en = 'An item for allocating interest repayments.'; ru = 'Статья для распределения оплаты процентов.';pl = 'Pozycja do przydzielenia spłaty odsetek.';es_ES = 'Un artículo para asignar los reembolsos de intereses.';es_CO = 'Un artículo para asignar los reembolsos de intereses.';tr = 'Faiz geri ödemelerini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione dei rimborsi di interessi.';de = 'Posten für Zuweisen von Zinsrückzahlung.'");
		Items.GLAccount.ToolTip				= NStr("en = 'An account for recording principal payable.'; ru = 'Счет для учета основного долга к оплате.';pl = 'Konto do ewidencjonowania kwoty głównej do spłaty.';es_ES = 'Una cuenta para registrar el capital a pagar.';es_CO = 'Una cuenta para registrar el capital a pagar.';tr = 'Ödenecek anaparayı kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione del capitale da pagare.';de = 'Ein Konto für Buchen der zahlbaren Darlehenshöhe.'");
		Items.InterestGLAccount.ToolTip		= NStr("en = 'An account for recording interest payable.'; ru = 'Счет для учета процентов к оплате.';pl = 'Konto do ewidencjonowania odsetek do spłaty.';es_ES = 'Una cuenta para registrar los intereses a pagar.';es_CO = 'Una cuenta para registrar los intereses a pagar.';tr = 'Ödenecek faizi kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione degli interessi passivi.';de = 'Ein Konto für Buchen der zahlbaren Zinsen.'");
		Items.CommissionExpenseItem.ToolTip	= NStr("en = 'An item for allocating commission expenses.'; ru = 'Статья для распределения расходов на комиссию.';pl = 'Pozycja do przydzielenia spłaty rozchodów na prowizję.';es_ES = 'Un artículo para asignar los gastos de las comisiones.';es_CO = 'Un artículo para asignar los gastos de las comisiones.';tr = 'Komisyon giderini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione delle spese di commissione.';de = 'Ein Konto für Zuweisen der zahlbaren Ausgaben.'");
		Items.CostAccount.ToolTip			= NStr("en = 'An account for recording interest repayments.'; ru = 'Счет для учета оплаты процентов.';pl = 'Konto do ewidencjonowania spłaty odsetek.';es_ES = 'Una cuenta para registrar los reembolsos de intereses.';es_CO = 'Una cuenta para registrar los reembolsos de intereses.';tr = 'Faiz geri ödemelerini kaydetmeye yönelik hesap.';it = 'Un conto per registrare i rimborsi di interessi.';de = 'Ein Konto für Buchen der fälligen Rückzahlungen.'");
		Items.CommissionGLAccount.ToolTip	= NStr("en = 'An account for recording commission payable.'; ru = 'Счет для учета комиссии к оплате.';pl = 'Konto do ewidencjonowania prowizji do spłaty.';es_ES = 'Una cuenta para registrar las comisiones a pagar.';es_CO = 'Una cuenta para registrar las comisiones a pagar.';tr = 'Ödenecek komisyonu kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione delle commissioni da pagare.';de = 'Ein Konto für Buchen der zahlbaren Provisionszahlung.'");
		Items.CostAccountCommission.ToolTip	= NStr("en = 'An account for recording commission expenses.'; ru = 'Счет для учета расходов на комиссию.';pl = 'Konto do ewidencjonowania rozchodów na prowizję.';es_ES = 'Una cuenta para registrar los gastos de las comisiones.';es_CO = 'Una cuenta para registrar los gastos de las comisiones.';tr = 'Komisyon giderlerini kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione delle spese di commissione.';de = 'Ein Konto für Buchen von Provisionszahlungsausgaben'");
		
	ElsIf Object.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
		
		Items.InterestIncomeItem.ToolTip	= NStr("en = 'An item for allocating interest income.'; ru = 'Статья для распределения процентного дохода.';pl = 'Pozycja do przydzielenia dochodów od odsetek.';es_ES = 'Un artículo para asignar los ingresos por intereses.';es_CO = 'Un artículo para asignar los ingresos por intereses.';tr = 'Faiz gelirini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione degli interessi attivi.';de = 'Posten für Zuweisen von Zinsertrag.'");
		Items.GLAccount.ToolTip				= NStr("en = 'An account for recording principal receivable from a counterparty.'; ru = 'Счет для учета основного долга контрагента к поступлению.';pl = 'Konto do ewidencjonowania kwoty głównej należnej od kontrahenta.';es_ES = 'Una cuenta para registrar el capital a cobrar de una contrapartida.';es_CO = 'Una cuenta para registrar el capital a cobrar de una contrapartida.';tr = 'Cari hesaptan alınan anaparayı kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione del credito in conto capitale da ricevere da una controparte.';de = 'Ein Konto für Buchen von Darlehenshöhe zahlbar von einem Geschäftspartner.'");
		Items.InterestGLAccount.ToolTip		= NStr("en = 'An account for recording interest receivable from a counterparty.'; ru = 'Счет для учета процентов к поступлению от контрагента.';pl = 'Konto do ewidencjonowania odsetek należnych od kontrahenta.';es_ES = 'Una cuenta para registrar los intereses a cobrar de una contrapartida.';es_CO = 'Una cuenta para registrar los intereses a cobrar de una contrapartida.';tr = 'Cari hesaptan alınan faizi kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione degli interessi da ricevere da una controparte.';de = 'Ein Konto für Buchen Zinsen zahlbar von einem Geschäftspartner.'");
		Items.CommissionExpenseItem.ToolTip	= NStr("en = 'An item for allocating commission income.'; ru = 'Статья для распределения комиссионного вознаграждения.';pl = 'Pozycja do przydzielenia spłaty dochodów od prowizji.';es_ES = 'Un artículo para asignar los ingresos por comisiones.';es_CO = 'Un artículo para asignar los ingresos por comisiones.';tr = 'Komisyon gelirini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione delle entrate da commissione.';de = 'Ein Posten für Zuweisung von Einnahmen der Provisionszahlung.'");
		Items.CostAccount.ToolTip			= NStr("en = 'An account for recording interest income.'; ru = 'Счет для учета процентного дохода.';pl = 'Konto do ewidencjonowania dochodów od odsetek.';es_ES = 'Una cuenta para registrar los ingresos por intereses.';es_CO = 'Una cuenta para registrar los ingresos por intereses.';tr = 'Faiz gelirini kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione degli interessi attivi.';de = 'Ein Konto für Buchen von Zinsertrag.'");
		Items.CommissionGLAccount.ToolTip	= NStr("en = 'An account for recording commission income.'; ru = 'Счет для учета комиссионного вознаграждения.';pl = 'Konto do ewidencjonowania dochodów od prowizji.';es_ES = 'Una cuenta para registrar los ingresos por comisiones.';es_CO = 'Una cuenta para registrar los ingresos por comisiones.';tr = 'Komisyon gelirini kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione delle entrate da commissione.';de = 'Ein Konto für Buchen der Einnahme der Provisionszahlung.'");
		Items.CostAccountCommission.ToolTip	= NStr("en = 'An item for allocating commission income.'; ru = 'Статья для распределения комиссионного вознаграждения.';pl = 'Pozycja do przydzielenia spłaty dochodów od prowizji.';es_ES = 'Un artículo para asignar los ingresos por comisiones.';es_CO = 'Un artículo para asignar los ingresos por comisiones.';tr = 'Komisyon gelirini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione delle entrate da commissione.';de = 'Ein Posten für Zuweisung von Einnahmen der Provisionszahlung.'");
		
	Else
		
		Items.InterestIncomeItem.ToolTip		= NStr("en = 'An item for allocating interest income.'; ru = 'Статья для распределения процентного дохода.';pl = 'Pozycja do przydzielenia dochodów od odsetek.';es_ES = 'Un artículo para asignar los ingresos por intereses.';es_CO = 'Un artículo para asignar los ingresos por intereses.';tr = 'Faiz gelirini tahsis etmeye yönelik kalem.';it = 'Una voce per l''allocazione degli interessi attivi.';de = 'Posten für Zuweisen von Zinsertrag.'");
		Items.GLAccount.ToolTip					= NStr("en = 'An account for recording principal receivable from an employee.'; ru = 'Счет для учета основного долга сотрудника к поступлению.';pl = 'Konto do ewidencjonowania kwoty głównej należnej od pracownika.';es_ES = 'Una cuenta para registrar el capital a cobrar de un empleado.';es_CO = 'Una cuenta para registrar el capital a cobrar de un empleado.';tr = 'Çalışandan alınan anaparayı kaydetmeye yönelik hesap.';it = 'Conto per la registrazione del credito in conto capitale nei confronti di un dipendente.';de = 'Ein Konto für Buchen der Darlehenshöhe zahlbar von einem Mitarbeiter.'");
		Items.InterestGLAccount.ToolTip			= NStr("en = 'An account for recording interest receivable from an employee.'; ru = 'Счет для учета процентов к поступлению от сотрудника.';pl = 'Konto do ewidencjonowania odsetek należnych od pracownika.';es_ES = 'Una cuenta para registrar los intereses a cobrar de un empleado.';es_CO = 'Una cuenta para registrar los intereses a cobrar de un empleado.';tr = 'Çalışandan alınan faizi kaydetmeye yönelik hesap.';it = 'Un conto per la registrazione degli interessi da ricevere da un dipendente.';de = 'Ein Konto für Buchen von Zinsen zahlbar von einem Mitarbeiter.'");
		Items.CostAccount.ToolTip				= NStr("en = 'An account for recording interest income on a loan.'; ru = 'Счет для учета процентного дохода по кредиту.';pl = 'Konto do ewidencjonowania dochodów od pożyczki.';es_ES = 'Una cuenta para registrar los ingresos por intereses de un préstamo.';es_CO = 'Una cuenta para registrar los ingresos por intereses de un préstamo.';tr = 'Krediden faiz gelirini kaydetmeye yönelik hesap.';it = 'Conto per la registrazione degli interessi attivi su un prestito.';de = 'Ein Konto für Buchen von Zinsertrags für ein Darlehen.'");
		Items.DeductionPrincipalDebt.ToolTip	= NStr("en = 'The type of the principal repayment deduction applied to payroll calculations.'; ru = 'Тип вычета по выплате основного долга, применяемого к расчетам заработной платы.';pl = 'Typ potrącenia spłaty kwoty głównej zastosowany do obliczenia wynagrodzenia.';es_ES = 'El tipo de deducción por reembolso del capital que se aplica en los cálculos de nóminas.';es_CO = 'El tipo de deducción por reembolso del capital que se aplica en los cálculos de nóminas.';tr = 'Bordro hesaplamalarına uygulanan anapara geri ödeme kesintisinin türü.';it = 'Il tipo di detrazione per il rimborso del capitale applicata al calcolo delle retribuzioni.';de = 'Der Typ von Abzügen von Rückzahlung der Darlehenshöhe verwendet für Berechnung von Lohn und Gehalt.'");
		Items.DeductionInterest.ToolTip			= NStr("en = 'The type of the interest repayment deduction applied to payroll calculations.'; ru = 'Тип вычета по выплате процентов, применяемого к расчетам заработной платы.';pl = 'Typ potrącenia spłaty odsetek zastosowany do obliczenia wynagrodzenia.';es_ES = 'El tipo de deducción por reembolso de intereses que se aplica al cálculo de nóminas.';es_CO = 'El tipo de deducción por reembolso de intereses que se aplica al cálculo de nóminas.';tr = 'Bordro hesaplamalarına uygulanan faiz geri ödeme kesintisinin türü.';it = 'Il tipo di detrazione per interessi applicata al calcolo delle retribuzioni.';de = 'Der Typ von Abzügen von Rückzahlung der Zinsen verwendet für Berechnung von Lohn und Gehalt.'");
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

// Procedure clears attributes depending on the selected contract kind.
//
&AtServer
Procedure ClearAttributesNotRelatedToLoanKind()

	If Object.LoanKind = LoanKindLoanContract Then
		
		Object.Counterparty		= Undefined;
		Object.Commission = 0;	
		
		For Each CurrentScheduleLine In Object.PaymentsAndAccrualsSchedule Do				
			CurrentScheduleLine.Commission = 0;
			RecalculatePaymentAmountOnServer(CurrentScheduleLine);		
		EndDo;
		
	Else
		Object.Employee = Undefined;
	EndIf;
	
EndProcedure

// Procedure sets attribute visibility depending on GL account type.
//
&AtServer
Procedure SetAccountingParameterVisibilityOnServer()

	If Object.InterestExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses 
		Or Object.CommissionExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
		
		AccountingParameterVisibility = True;
	Else
		AccountingParameterVisibility = False;
	EndIf;
	
	Items.StructuralUnit.Visible	= AccountingParameterVisibility;
	Items.BusinessArea.Visible		= AccountingParameterVisibility;
	Items.Order.Visible				= AccountingParameterVisibility;
	
EndProcedure

// Procedure fills in attributes by default depending on GL account type.
//
&AtServer
Procedure PopulateAccountingParameterValuesByDefaultOnServer()
	
	If Object.InterestExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses 
		Or Object.CommissionExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
		
		If Not ValueIsFilled(Object.StructuralUnit) Then
			SettingValue = DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.StructuralUnit = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;
		
		Object.Order = Undefined;
		
	EndIf;
	
EndProcedure

// Procedure sets up items which are used for setting and filling in credit (loan) commission.
//
&AtServer
Procedure ConfigureItemsByCommissionTypeAndLoanKind()
	
	If Object.LoanKind = Enums.LoanContractTypes.Borrowed 
		Or Object.LoanKind = Enums.LoanContractTypes.CounterpartyLoanAgreement Then
		
		Items.CommissionBySchedule.Visible	= True;
		Items.CommissionType.Visible		= True;
		Items.CommissionAmount.Visible		= True;
		
		ThereCommission	= (Object.CommissionType <> Enums.LoanCommissionTypes.No);
		
		Items.CommissionAmount.Visible 								= ThereCommission AND (Object.CommissionType <> Enums.LoanCommissionTypes.CustomSchedule);
		Items.PaymentsAndAccrualsScheduleCommissionAmount.Visible	= ThereCommission;
		Items.CommissionGLAccount.Visible 							= ThereCommission;
		Items.CommissionItem.Visible = (Object.CommissionType <> Enums.LoanCommissionTypes.No);
		
	Else
		
		Items.PaymentsAndAccrualsScheduleCommissionAmount.Visible	= False;
		Items.CommissionType.Visible								= False;
		Items.CommissionAmount.Visible								= False;
		Items.CommissionBySchedule.Visible							= False;
		Items.CommissionGLAccount.Visible							= False;
		Items.CommissionItem.Visible								= False;
	EndIf;
	
	Items.RateExplanation.Visible = GetFunctionalOption("ForeignExchangeAccounting");
	
EndProcedure

#EndRegion

#Region FillInScheduleAndCalculatePaymentAmount

// Function returns the table with a repayment (payment) schedule if credit (loan) provision dates are in one month.
//
&AtServer
Function RepaymentScheduleOneMonth(PaymentAmount)
	
	RepaymentScheduleTable = New ValueTable;
	
	RepaymentScheduleTable.Columns.Add("MonthNumber", 				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("Month",						New TypeDescription("Date"));
	RepaymentScheduleTable.Columns.Add("PaymentDate",				New TypeDescription("Date"));	
	RepaymentScheduleTable.Columns.Add("RemainingDebt",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestAccrual", 			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestRepayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionAccrual", 		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionRepayment",		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("DebtRepayment",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MonthlyPayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MutualSettlementBalance",	New TypeDescription("Number"));
	
	// Process the situation when a loan is issued within one month.
	DaysInMonth = Day(Object.Maturity) - Day(Object.Issued) + 1; // Interest is accrued starting from the day after issue until the payment day inclusive.
		
	AccruedInterest 		= Object.Total * Object.InterestRate * 0.01 * DaysInMonth / NumberOfDaysInYear(Year(Object.Issued), Object.DaysInYear360);
	AccruedCommission 		= GetCommissionAmount(Object.Total);
	AccruedPrincipalDebt	= Object.Total;

	MonthlyPayment = AccruedInterest + AccruedPrincipalDebt + AccruedCommission;
	
	// Monthly payment loan amount and interest.
	ScheduleLine = RepaymentScheduleTable.Add();
	ScheduleLine.MonthNumber				= 1;
	ScheduleLine.RemainingDebt				= 0; 
	ScheduleLine.InterestAccrual			= AccruedInterest; 
	ScheduleLine.InterestRepayment			= AccruedInterest;
	ScheduleLine.CommissionAccrual			= AccruedCommission; 
	ScheduleLine.CommissionRepayment		= AccruedCommission;
	ScheduleLine.DebtRepayment				= AccruedPrincipalDebt; 
	ScheduleLine.MonthlyPayment				= MonthlyPayment;
	ScheduleLine.MutualSettlementBalance	= 0;
	ScheduleLine.PaymentDate				= EndOfDay(Object.Maturity)+1;
	
	Return RepaymentScheduleTable;
	
EndFunction

// Function returns the table with a repayment (payment) schedule if credit (loan) provision dates are in different months.
//
&AtServer
Function RepaymentScheduleSeveralMonths(PaymentAmount)
	
	RepaymentScheduleTable = New ValueTable;
	
	RepaymentScheduleTable.Columns.Add("MonthNumber", 				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("Month",						New TypeDescription("Date"));
	RepaymentScheduleTable.Columns.Add("PaymentDate",				New TypeDescription("Date"));	
	RepaymentScheduleTable.Columns.Add("RemainingDebt",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestAccrual", 			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestRepayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionAccrual", 		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionRepayment",		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("DebtRepayment",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MonthlyPayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MutualSettlementBalance",	New TypeDescription("Number"));
	
	// Determine some frequently used parameters.
	EndDate			= Object.Maturity;
	Issued			= Object.Issued;
	EndMonth		= BegOfMonth(Object.Maturity);
	PaymentAmount	= PaymentAmount;
	RepaymentAmount	= PaymentAmount;
	PaymentTerms	= Object.PaymentTerms;
	
	// Process the situation when a loan is issued within several months.
	// Populate the structure array, determine the function result for interpolation search according to the Remaining debt
	// field in the last item of the array.
	RemainingDebt				= Object.Total;
	AccumulatedInterest			= 0;
	AccumulatedPrincipalDebt	= 0;
	MutualSettlementBalance		= RemainingDebt;
	MonthNumber					= 1;
	
	// Payment kinds when the payment amount is determined according to the principal debt repayment amount and not
	// specified by the fixed amount.
	PaymentTermsRepaymentAmount = New Array;
	PaymentTermsRepaymentAmount.Add(Enums.LoanRepaymentTerms.FixedPrincipalPayments);
	PaymentTermsRepaymentAmount.Add(Enums.LoanRepaymentTerms.OnlyPrincipal);
	
	FirstRepayment = ?(Object.FirstRepayment = '00010101', AddMonth(Object.Issued, 1), Object.FirstRepayment);
	FirstRepaymentEqualsToMonthEnd = (EndOfDay(FirstRepayment) = EndOfMonth(FirstRepayment)); // If you add 1 month to 01/31, it will become 02/28 (or 02/29). If you add a month to 02/29, it will become 03/29, i.e. not the end of the month.
	
	NextPaymentDate = AddMonth(FirstRepayment, -1);
	
	If FirstRepaymentEqualsToMonthEnd Then
		NextPaymentDate = EndOfMonth(NextPaymentDate);
	EndIf;
	
	StartMonth		= BegOfMonth(NextPaymentDate);
	CurrentMonth	= StartMonth;
	
	While NextPaymentDate < EndDate Do
		
		// Example: payroll month from 04/10 - 05/10, i.e. from 04/10 to 05/09, and payment date is 05/10.
		// Calculate interest for a month.
		PreviousPaymentDate = NextPaymentDate;
		PaymentDate = AddMonth(NextPaymentDate, 1);
		
		If FirstRepaymentEqualsToMonthEnd Then
			PaymentDate = EndOfMonth(PaymentDate);
		EndIf;
		
		NextPaymentDate					= Min(PaymentDate, EndOfDay(EndDate) + 1);
		DaysInYearPreviousPaymentDate	= NumberOfDaysInYear(Year(PreviousPaymentDate), Object.DaysInYear360);
		DaysInYearNextPaymentDate		= NumberOfDaysInYear(Year(NextPaymentDate), Object.DaysInYear360);
		
		/////////////////////////////////////////////////////////////////////////////////////////////////
		// Calculate parameters to the month end.
		If Object.DaysInYear360 Then
			DaysInMonth = 30 - Min(Day(PreviousPaymentDate), 30);
		Else
			DaysInMonth = Day(EndOfMonth(PreviousPaymentDate)) - Day(PreviousPaymentDate);
		EndIf;
		
		InterestAccrualPrevious = Max(RemainingDebt, 0) * Object.InterestRate * 0.01 * DaysInMonth / DaysInYearPreviousPaymentDate;
		InterestAccrualPrevious = Round(InterestAccrualPrevious, 2);
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
		// Decrease the repayment amount proportionally to the time passed (from the issue date).
			AccruedPrincipalDebtPrevious = RepaymentAmount * DaysInMonth / NumberOfMonthDays(PreviousPaymentDate, Object.DaysInYear360);
			AccruedPrincipalDebtPrevious = Round(AccruedPrincipalDebtPrevious, 2);
		EndIf;
			
		// //////////////////////////////////////////////////////////////////////////////////////////////
		// Calculate parameters from the month start.
		If Object.DaysInYear360 Then
			DaysInMonth = Min(Day(NextPaymentDate), 30);
		Else
			DaysInMonth = Day(NextPaymentDate);
		EndIf;
		
		InterestAccrualNext = Max(RemainingDebt, 0) * Object.InterestRate * 0.01 * DaysInMonth / DaysInYearNextPaymentDate;
		InterestAccrualNext = Round(InterestAccrualNext, 2);
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
		// Decrease the repayment amount proportionally to the time passed (from the issue date).
			AccruedPrincipalDebtNext	= RepaymentAmount * DaysInMonth / NumberOfMonthDays(NextPaymentDate, Object.DaysInYear360);
			AccruedPrincipalDebtNext	= Round(AccruedPrincipalDebtNext, 2);
		EndIf;
		
		InterestAccrual	= InterestAccrualPrevious + InterestAccrualNext;
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
			AccruedPrincipalDebt = AccruedPrincipalDebtPrevious + AccruedPrincipalDebtNext;
		Else
			AccruedPrincipalDebt = PaymentAmount - InterestAccrual;
		EndIf;
		
		// calculate repayment
		InterestRepayment	= 0;
		DebtRepayment		= 0;
		MonthlyPayment		= 0;
		
		If Object.RepaymentOption = Enums.OptionsOfLoanRepaymentByEmployee.MonthlyRepayment Then
			
			// Repaid within the period.
			If PaymentTerms = Enums.LoanRepaymentTerms.AnnuityPayments Then
				MonthlyPayment		= PaymentAmount;
				InterestRepayment	= InterestAccrual;
				DebtRepayment		= MonthlyPayment - InterestRepayment;
			ElsIf PaymentTerms = Enums.LoanRepaymentTerms.FixedPrincipalPayments Then
				InterestRepayment	= InterestAccrual;
				DebtRepayment		= AccruedPrincipalDebt;
			ElsIf PaymentTerms = Enums.LoanRepaymentTerms.OnlyPrincipal Then
				
				If CurrentMonth = EndMonth Then
					// Include the whole payment in the last month.
					InterestRepayment = AccumulatedInterest;
				EndIf;
				
				DebtRepayment = RepaymentAmount;
				
			ElsIf PaymentTerms = Enums.LoanRepaymentTerms.OnlyInterest Then
				
				If CurrentMonth = EndMonth Then
					// Include the whole payment in the last month.
					DebtRepayment = AccumulatedPrincipalDebt;
				EndIf;
				
				InterestRepayment = InterestAccrual;
				
			ElsIf PaymentTerms = Enums.LoanRepaymentTerms.CustomSchedule Then
				DebtRepayment = RepaymentAmount;
			EndIf;
			
		EndIf;
		
		// Include amount balance in the last month.
		If NextPaymentDate >= EndDate 
			AND	PaymentTerms <> Enums.LoanRepaymentTerms.AnnuityPayments Then
			// Include the whole payment in the last month.
			InterestRepayment	= AccumulatedInterest	+ InterestAccrual;
			DebtRepayment		= RemainingDebt;
		EndIf;
		
		CommissionAccrual	= GetCommissionAmount(RemainingDebt);
		CommissionAccrual	= Round(CommissionAccrual, 2);
		CommissionRepayment	= CommissionAccrual;
		
		// Monthly payment loan amount and interest.
		MonthlyPayment = DebtRepayment + InterestRepayment + CommissionRepayment;
		
		MutualSettlementBalance = MutualSettlementBalance + InterestAccrual + CommissionAccrual - MonthlyPayment;
		
		ScheduleLine = RepaymentScheduleTable.Add();
		ScheduleLine.MonthNumber				= MonthNumber;
		ScheduleLine.Month						= CurrentMonth; 
		ScheduleLine.RemainingDebt				= RemainingDebt; 
		ScheduleLine.InterestAccrual			= InterestAccrual; 
		ScheduleLine.InterestRepayment			= InterestRepayment;
		ScheduleLine.CommissionAccrual			= CommissionAccrual; 
		ScheduleLine.CommissionRepayment		= CommissionRepayment;
		ScheduleLine.DebtRepayment				= DebtRepayment; 
		ScheduleLine.MonthlyPayment				= MonthlyPayment;
		ScheduleLine.MutualSettlementBalance	= MutualSettlementBalance;
		ScheduleLine.PaymentDate				= NextPaymentDate;
		
		// updating counters
		RemainingDebt				= RemainingDebt - DebtRepayment;
		AccumulatedInterest			= AccumulatedInterest + InterestAccrual - InterestRepayment;
		AccumulatedPrincipalDebt	= AccumulatedPrincipalDebt + AccruedPrincipalDebt - DebtRepayment;
		
		CurrentMonth = AddMonth(CurrentMonth, 1);
		MonthNumber = MonthNumber + 1;
		
	EndDo;
	
	// Small debt amount may not have been allocated after allocation. Allocate it to principal debt by reducing interest.
	// Start from the last line.
	If MutualSettlementBalance <> 0 AND RepaymentScheduleTable.Count() > 0 Then
		
		Cnt = RepaymentScheduleTable.Count() - 1;
		
		If MutualSettlementBalance > 0 Then
			
			While MutualSettlementBalance > 0 AND Cnt >= 0 Do;
				ScheduleLine = RepaymentScheduleTable[Cnt];
				
				If ScheduleLine.InterestRepayment >= MutualSettlementBalance Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + MutualSettlementBalance;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - MutualSettlementBalance;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - MutualSettlementBalance;
					MutualSettlementBalance			= 0;
					
				ElsIf ScheduleLine.InterestRepayment > 0 Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + ScheduleLine.InterestRepayment;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - ScheduleLine.InterestRepayment;
					MutualSettlementBalance			= MutualSettlementBalance - ScheduleLine.InterestRepayment;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - ScheduleLine.InterestRepayment;
					
				EndIf;
				
				Cnt = Cnt - 1;			
			EndDo;
			
		Else
			
			While MutualSettlementBalance < 0 AND Cnt >= 0 Do;
				ScheduleLine = RepaymentScheduleTable[Cnt];
				
				If ScheduleLine.DebtRepayment >= -MutualSettlementBalance Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + MutualSettlementBalance;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - MutualSettlementBalance;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - MutualSettlementBalance;

					MutualSettlementBalance			= 0;
					
				ElsIf ScheduleLine.DebtRepayment > 0 Then
					
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual + ScheduleLine.DebtRepayment;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment + ScheduleLine.DebtRepayment;
					MutualSettlementBalance			= MutualSettlementBalance + ScheduleLine.DebtRepayment;
					ScheduleLine.DebtRepayment		= 0;
					
				EndIf;
				
				Cnt = Cnt - 1;
			EndDo;
			
		EndIf;
	EndIf;
	
	Return RepaymentScheduleTable;
	
EndFunction

// Fuction imitates loan repayment for the whole period with the specified parameters.
// Used while creating a repayment (payment) schedule, as well as while using methods of interpolation search for an
// optimal value of payment amount and repayment period.
// 
// Parameters:
//	- PaymentAmount - payment amount for which repayment schedule should be created.
//
// Returns - structure array with each structure representing a value describing loan repayment for a specific month.
//
&AtServer
Function RepaymentSchedule(PaymentAmount) Export
	
	// Determine some frequently used parameters.
	StartMonth	= BegOfMonth(Object.Issued);
	EndMonth	= BegOfMonth(Object.Maturity);
	
	// Process the situation when a loan is issued within one month.
	If StartMonth = EndMonth Then
		Return ValueToFormAttribute(RepaymentScheduleOneMonth(PaymentAmount),"RepaymentSchedule");
	Else
		Return ValueToFormAttribute(RepaymentScheduleSeveralMonths(PaymentAmount),"RepaymentSchedule");
	EndIf;
	
EndFunction

// Procedure fills in the payment schedule.
//
&AtServer
Procedure PopulatePaymentsAndAccrualsScheduleOnServer()
	
	Object.PaymentsAndAccrualsSchedule.Clear();
	
	PaymentAmount			= 0;
	MonthNumber				= 1;
	MutualSettlementBalance = Undefined;
	
	RepaymentSchedule(Object.PaymentAmount);
	
	RemainingDebt = Object.Total + RepaymentSchedule.Total("InterestAccrual") + RepaymentSchedule.Total("CommissionAccrual");
	AmountTotal		= RemainingDebt;
	ChargedAmount	= 0;
	
	For Each ScheduleLine In RepaymentSchedule Do
		
		RemainingDebt = RemainingDebt - ROUND(ScheduleLine.MonthlyPayment, 2);
		
		NewScheduleLine	= Object.PaymentsAndAccrualsSchedule.Add();
		NewScheduleLine.PaymentDate = ScheduleLine.PaymentDate;
		
		MonthlyPayment		= ScheduleLine.MonthlyPayment;
		CommissionRepayment = ScheduleLine.CommissionRepayment;

		NewScheduleLine.Commission		= CommissionRepayment;
		NewScheduleLine.PaymentAmount	= ScheduleLine.MonthlyPayment;
		NewScheduleLine.Principal		= ScheduleLine.DebtRepayment;
		NewScheduleLine.Interest		= ScheduleLine.InterestRepayment;
		
		ChargedAmount = ChargedAmount + NewScheduleLine.PaymentAmount;
		
		LineLoanKind = ?(Object.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement, 
						NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"),
						NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"));
		
		If Object.InterestRate <> 0 Then
			NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1% of total %2 amount repaid.'; ru = 'Процент суммы погашенного долга составляет %1% от суммы %2.';pl = 'spłacono %1% sumy %2.';es_ES = '%1% del importe %2 total pagado.';es_CO = '%1% del importe %2 total pagado.';tr = 'Toplam %2 tutarın %1%''si geri ödendi.';it = '%1% del totale %2 importo ripagato.';de = '%1% des Gesamt%2 betrags zurückgezahlt.'"),
				Format(ChargedAmount / AmountTotal * 100, "NFD=2; NZ=0"),
				LineLoanKind);
		Else
			NewScheduleLine.Comment = "";
		EndIf;
		
		NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 Debt balance is %2 (%3).'; ru = '%1 Остаток долга равен %2 (%3).';pl = '%1 Saldo zadłużenia wynosi %2 (%3).';es_ES = '%1 Saldo de la deuda es %2 (%3).';es_CO = '%1 Saldo de la deuda es %2 (%3).';tr = '%1Borç bakiyesi %2(%3).';it = '%1 saldo del debito è %2 (%3).';de = '%1 Schuldenstand ist %2 (%3).'"),
				NewScheduleLine.Comment,
				Format(RemainingDebt, "NFD=2; NZ=0"),
				Object.SettlementsCurrency);
		
		MonthNumber = MonthNumber + 1;
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtServer
Function GetCommissionAmount(RemainingDebt) Export
	
	If Object.CommissionType = Enums.LoanCommissionTypes.PercentOfPrincipal Then
		CommissionAmount = Object.Total * Object.Commission / 100;
	ElsIf Object.CommissionType = Enums.LoanCommissionTypes.PercentOfPrincipalBalance Then
		CommissionAmount = RemainingDebt * Object.Commission / 100;
	ElsIf Object.CommissionType = Enums.LoanCommissionTypes.AmountPerMonth Then
		CommissionAmount = Object.Commission;
	Else
		CommissionAmount = 0;
	EndIf;
	
	Return CommissionAmount;
	
EndFunction

// Procedure updates information in the Comment field of the PaymentsAndAccrualsSchedule tabular section.
//
&AtClient
Procedure UpdateInformationInFieldComment(Command)
	
	LineLoanKind = ?(Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.EmployeeLoanAgreement"), 
	NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"),
	NStr("en = 'loan'; ru = 'займа';pl = 'pożyczkowy';es_ES = 'préstamo';es_CO = 'préstamo';tr = 'kredi';it = 'prestito';de = 'darlehen'"));
	
	RemainingDebt	= Object.Total + Object.PaymentsAndAccrualsSchedule.Total("Interest") + Object.PaymentsAndAccrualsSchedule.Total("Commission");
	AmountTotal		= RemainingDebt;
	ChargedAmount	= 0;
	
	For Each ScheduleLine In Object.PaymentsAndAccrualsSchedule Do
		RemainingDebt = RemainingDebt - ScheduleLine.PaymentAmount;
		ChargedAmount = ChargedAmount + ScheduleLine.PaymentAmount;
		
		If Object.InterestRate <> 0 Then
			ScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1% of total %2 amount repaid.'; ru = 'Процент суммы погашенного долга составляет %1% от суммы %2.';pl = 'spłacono %1% sumy %2.';es_ES = '%1% del importe %2 total pagado.';es_CO = '%1% del importe %2 total pagado.';tr = 'Toplam %2 tutarın %1%''si geri ödendi.';it = '%1% del totale %2 importo ripagato.';de = '%1% des Gesamt%2 betrags zurückgezahlt.'"),
			Format(ChargedAmount / AmountTotal * 100, "NFD=2; NZ=0"),
			LineLoanKind);
		Else
			ScheduleLine.Comment = "";
		EndIf;
		
		ScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 Debt balance is %2 (%3).'; ru = '%1 Остаток долга равен %2 (%3).';pl = '%1 Saldo zadłużenia wynosi %2 (%3).';es_ES = '%1 Saldo de la deuda es %2 (%3).';es_CO = '%1 Saldo de la deuda es %2 (%3).';tr = '%1Borç bakiyesi %2(%3).';it = '%1 saldo del debito è %2 (%3).';de = '%1 Schuldenstand ist %2 (%3).'"),
				ScheduleLine.Comment,
				Format(RemainingDebt, "NFD=2; NZ=0"),
				Object.SettlementsCurrency);

	EndDo;
	
EndProcedure

// Method selects the amount of annuity payment (fixed for the whole loan repayment period).
//
// Parameters:
// - LoanData - structure
&AtClient
Function AnnuityPaymentAmount() Export
	
	// Search for the suitable payment amount using interpolation search:
	// - in the first approximation, the payment amount is equal to the annuity payment on one-off issue of all tranches
	// - receive the remaining debt after effecting all payments of this amount
	// - in the second approximation, the payment amount is 20% less
	// than annuity payment on one-off payment
	// - then decrease the payment amount proportionally to the remaining debt change.
	
	// Make the first assumption.
	Total = Object.Total;
	If BegOfMonth(Object.Issued) = BegOfMonth(Object.Maturity) Then
		
		DaysInMonth = Day(Object.Maturity) - Day(Object.Issued) + 1; // Interest is accrued starting from the day after issue until the payment day inclusive.
		AccruedInterest = Object.Total * Object.InterestRate * 0.01 * DaysInMonth / NumberOfDaysInYear(Year(Object.Issued), Object.DaysInYear360);
		
		Return Total + AccruedInterest;
		
	Else
		
		PreviousPaymentAmount = Total * LoansToEmployeesClientServer.AnnuityCoefficient(
					LoansToEmployeesClientServer.InterestRatePerMonth(Object.InterestRate) * 0.01, 
					LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, Object.Issued));
		PreviousRemainingDebt = MutualSettlementBalanceUponCompletion(PreviousPaymentAmount);
		
		// No need to calculate if PreviousPaymentAmount fully covers the debt.
		If Not ValueIsFilled(PreviousRemainingDebt) Then
			Return PreviousPaymentAmount;
		EndIf;

		// Make the second assumption.
		CurrentPaymentAmount = PreviousPaymentAmount * 0.8;
		CurrentRemainingDebt = MutualSettlementBalanceUponCompletion(CurrentPaymentAmount);
		
		// Select payment amount until the selected amount does not lead to zero balance after all payments.
		While Round(CurrentRemainingDebt, 2) <> 0 
			AND (Round(CurrentRemainingDebt, 2) > 0.01 OR Round(CurrentRemainingDebt, 2) < -0.01)
			AND CurrentPaymentAmount <> PreviousPaymentAmount 
			AND CurrentRemainingDebt <> PreviousRemainingDebt Do
			
			ChangePaymentAmount		= CurrentPaymentAmount - PreviousPaymentAmount;
			PreviousPaymentAmount	= CurrentPaymentAmount;
			CurrentPaymentAmount	= CurrentPaymentAmount - ChangePaymentAmount - (PreviousRemainingDebt / (CurrentRemainingDebt - PreviousRemainingDebt)) * ChangePaymentAmount;
			PreviousRemainingDebt	= CurrentRemainingDebt;
			CurrentRemainingDebt	= MutualSettlementBalanceUponCompletion(CurrentPaymentAmount);
			
		EndDo;
		
		Return CurrentPaymentAmount;
		
	EndIf;
	
EndFunction

// Function determines a closing balance after all effected payments of this amount according to the fixed payment amount.
// Used for interpolation search for the payment amount.
// 
// Parameters:
// - PaymentAmount - fixed payment amount.
//
&AtClient
Function MutualSettlementBalanceUponCompletion(PaymentAmount)
	
	 RepaymentSchedule(PaymentAmount);
				
	If RepaymentSchedule.Count() = 0 Then
		Return Object.Total;
	EndIf;
	
	BalanceUponCompletion = RepaymentSchedule[RepaymentSchedule.Count()-1].MutualSettlementBalance;
	If BalanceUponCompletion <> 0 Then
		Return BalanceUponCompletion;
	EndIf;
	
	PostalCode = RepaymentSchedule.Count() - 1;
	While PostalCode >= 0 Do
		If RepaymentSchedule[PostalCode].RemainingDebt <> 0 Then
			Return RepaymentSchedule[PostalCode].MutualSettlementBalance;
		EndIf;
		PostalCode = PostalCode - 1;
	EndDo;
	
EndFunction

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

// End StandardSubsystems.Properties

#EndRegion
