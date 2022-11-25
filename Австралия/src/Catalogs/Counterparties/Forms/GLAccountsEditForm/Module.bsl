#Region EventsHandlers

// Function checks account change option.
//
&AtServer
Function CancelGLAccountWithCustomerChange(Ref)
	
	Query = New Query(
	"SELECT ALLOWED
	|	AccountsReceivable.Period,
	|	AccountsReceivable.Recorder,
	|	AccountsReceivable.LineNumber,
	|	AccountsReceivable.Active,
	|	AccountsReceivable.RecordType,
	|	AccountsReceivable.Company,
	|	AccountsReceivable.SettlementsType,
	|	AccountsReceivable.Counterparty,
	|	AccountsReceivable.Contract,
	|	AccountsReceivable.Document,
	|	AccountsReceivable.Order,
	|	AccountsReceivable.Amount,
	|	AccountsReceivable.AmountCur,
	|	AccountsReceivable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Counterparty = &Counterparty");
	
	Query.SetParameter("Counterparty", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Function checks account change option.
//
&AtServer
Function CancelGLAccountWithVendorChange(Ref)
	
	Query = New Query(
	"SELECT ALLOWED
	|	AccountsPayable.Period,
	|	AccountsPayable.Recorder,
	|	AccountsPayable.LineNumber,
	|	AccountsPayable.Active,
	|	AccountsPayable.RecordType,
	|	AccountsPayable.Company,
	|	AccountsPayable.SettlementsType,
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.Document,
	|	AccountsPayable.Order,
	|	AccountsPayable.Amount,
	|	AccountsPayable.AmountCur,
	|	AccountsPayable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Counterparty = &Counterparty");
	
	Query.SetParameter("Counterparty", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountCustomerSettlements = Parameters.GLAccountCustomerSettlements;
	CustomerAdvancesGLAccount = Parameters.CustomerAdvancesGLAccount;
	GLAccountVendorSettlements = Parameters.GLAccountVendorSettlements;
	VendorAdvancesGLAccount = Parameters.VendorAdvancesGLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountWithCustomerChange(Ref) Then
		Items.WithCustomer.ToolTip = NStr("en = 'Records are registered for this customer in the infobase. Cannot change the GL accounts for this customer.'; ru = 'В базе есть движения по этому покупателю! Изменение счетов учета расчетов с покупателем запрещено!';pl = 'W bazie informacyjnej są zarejestrowane zapisy dla tego klienta. Nie można zmienić kont ewidencji dla tego klienta.';es_ES = 'Grabaciones se han registrado para este cliente en la infobase. No se puede cambiar las cuentas del libro mayor para este cliente.';es_CO = 'Grabaciones se han registrado para este cliente en la infobase. No se puede cambiar las cuentas del libro mayor para este cliente.';tr = 'Bu müşterinin kayıtları veri bankasında kayıtlıdır. Bu müşterinin Muhasebe hesaplarını değiştiremezsiniz.';it = 'Le registrazioni sono registrate per questo cliente nell''infobase. Impossibile modificare il conto mastro per questo cliente.';de = 'Datensätze werden für diesen Kunden in der Infobase registriert. Die Hauptbuch-Konten für diesen Kunden können nicht geändert werden.'");
		Items.WithCustomer.Enabled = False;
	EndIf;
		
	If CancelGLAccountWithVendorChange(Ref) Then
		Items.WithVendor.ToolTip = NStr("en = 'Records are registered for this supplier in the infobase. Cannot change the GL accounts for this supplier.'; ru = 'В базе есть движения по этому поставщику! Изменение счетов учета расчетов с поставщиком запрещено!';pl = 'W bazie informacyjnej są zarejestrowane zapisy dla tego dostawcy. Nie można zmienić kont ewidencji tego dostawcy.';es_ES = 'Grabaciones se han registrado para este proveedor en la infobase. No se puede cambiar las cuentas del libro mayor para este proveedor.';es_CO = 'Grabaciones se han registrado para este proveedor en la infobase. No se puede cambiar las cuentas del libro mayor para este proveedor.';tr = 'Bu tedarikçinin kayıtları veri bankasında kayıtlıdır. Bu tedarikçinin Muhasebe hesaplarını değiştiremezsiniz.';it = 'Le registrazioni sono registrate per questo fornitore nell''infobase. Impossibile modificare il conto mastro per questo fornitore.';de = 'Buchungen werden für diesen Lieferanten in der Infobase registriert. Die Hauptbuch-Konten für diesen Lieferanten können nicht geändert werden.'");
		Items.WithVendor.Enabled = False;
	EndIf;
	
	If Not Items.WithCustomer.Enabled
		AND Not Items.WithVendor.Enabled Then
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure Default(Command)
	
	DefaultAtServer();
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	If Items.WithCustomer.Enabled Then
		GLAccountCustomerSettlements	= GetDefaultGLAccount("AccountsReceivable");
		CustomerAdvancesGLAccount		= GetDefaultGLAccount("CustomerAdvances");
	EndIf;
	
	If Items.WithVendor.Enabled Then
		GLAccountVendorSettlements	= GetDefaultGLAccount("AccountsPayable");
		VendorAdvancesGLAccount		= GetDefaultGLAccount("AdvancesToSuppliers");
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccountCustomerSettlements, CustomerAdvanceGLAccount, GLAccountVendorSettlements, AdvanceGLAccountToSupplier",
		GLAccountCustomerSettlements, CustomerAdvancesGLAccount, GLAccountVendorSettlements, VendorAdvancesGLAccount
	);
	
	Notify("SettlementAccountsAreChanged", ParameterStructure);
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure GLAccountCustomerSettlementsOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountCustomerSettlements) Then
		GLAccountCustomerSettlements = GetDefaultGLAccount("AccountsReceivable");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure CustomerAdvancesGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(CustomerAdvancesGLAccount) Then
		CustomerAdvancesGLAccount = GetDefaultGLAccount("CustomerAdvances");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountVendorSettlementsOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountVendorSettlements) Then
		GLAccountVendorSettlements = GetDefaultGLAccount("AccountsPayable");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure VendorAdvancesGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(VendorAdvancesGLAccount) Then
		VendorAdvancesGLAccount = GetDefaultGLAccount("AdvancesToSuppliers");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
