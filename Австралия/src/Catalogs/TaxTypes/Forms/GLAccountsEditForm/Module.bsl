
#Region GeneralPurposeProceduresAndFunctions

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT ALLOWED
	|	TaxPayable.Period,
	|	TaxPayable.Recorder,
	|	TaxPayable.LineNumber,
	|	TaxPayable.Active,
	|	TaxPayable.RecordType,
	|	TaxPayable.Company,
	|	TaxPayable.TaxKind,
	|	TaxPayable.Amount,
	|	TaxPayable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.TaxPayable AS TaxPayable
	|WHERE
	|	TaxPayable.TaxKind = &TaxKind");
	
	Query.SetParameter("TaxKind", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	GLAccountForReimbursement = Parameters.GLAccountForReimbursement;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'GL accounts can not be edited if used in an accounting transaction.'; ru = 'Счета учета нельзя редактировать, если они используются в бухгалтерской транзакции.';pl = 'Konta księgowe nie mogą być edytowane, jeśli są używane w transakcji księgowej.';es_ES = 'Las cuentas del libro mayor no pueden ser editadas si se utilizan en una transacción contable.';es_CO = 'Las cuentas del libro mayor no pueden ser editadas si se utilizan en una transacción contable.';tr = 'Bir muhasebe işleminde kullanılıyorsa, Muhasebe hesapları düzenlenemez.';it = 'Il conto mastro non può essere modificato se utilizzato in transazioni contabili.';de = 'Hauptbuch-Konten können nicht bearbeitet werden, wenn sie in einem Buchhaltungsvorgang verwendet werden.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	DefaultAtServer();
	NotifyAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	GLAccount					= GetDefaultGLAccount("TaxPayable");
	GLAccountForReimbursement	= GetDefaultGLAccount("TaxRefund");	
		
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount, GLAccountForReimbursement",
		GLAccount, GLAccountForReimbursement
	);
	
	Notify("AccountsTaxTypesChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount("TaxPayable");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountForReimbursementOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountForReimbursement) Then
		GLAccountForReimbursement = GetDefaultGLAccount("TaxRefund");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
