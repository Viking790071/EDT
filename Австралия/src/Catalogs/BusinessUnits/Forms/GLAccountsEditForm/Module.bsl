
#Region GeneralPurposeProceduresAndFunctions

// Function checks account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT ALLOWED
	|	TRUE
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|WHERE
	|	POSSummary.StructuralUnit = &StructuralUnit");
	
	Query.SetParameter("StructuralUnit", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountInRetail = Parameters.GLAccountInRetail;
	MarkupGLAccount = Parameters.MarkupGLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this retail outlet in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этой розничной точке! Изменение счета учета запрещено!';pl = 'W bazie informacyjnej są zarejestrowane wpisy dla tego punktu sprzedaży. Nie można zmienić konta ewidencji.';es_ES = 'Grabaciones se han registrado para este punto de venta al por menor en la base de información. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para este punto de venta al por menor en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Infobase''de bu perakende satış noktası için kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Nel database ci sono movimenti per questo punto vendita! La modifica del conto mastro è vietata!';de = 'Die Datensätze werden für diese Verkaufsstelle in der Infobase registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
	ThisIsRetailEarningAccounting = Ref.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	DefaultAtServer();
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	GLAccountInRetail	= GetDefaultGLAccount("Inventory");
	MarkupGLAccount		= GetDefaultGLAccount("RetailMarkup");
		
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccountInRetail, MarkupGLAccount",
		GLAccountInRetail, MarkupGLAccount
	);
	
	Notify("AccountsChangedBusinessUnits", ParameterStructure);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ThisIsRetailEarningAccounting Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'You can edit GL accounts only for POS with retail inventory method (RIM).'; ru = 'Счета учетов редактируются только для розницы с суммовым учетом!';pl = 'Możesz edytować konto księgowe tylko dla punktu sprzedaży metody inwentaryzacji w sprzedaży detalicznej.';es_ES = 'Usted puede editar las cuentas del libro mayor solo para TPV con el método de inventario de la venta al por menor (RIM).';es_CO = 'Usted puede editar las cuentas del libro mayor solo para TPV con el método de inventario de la venta al por menor (RIM).';tr = 'Muhasebe hesapları yalnızca envanter perakende yöntemi olan POS için düzenlenebilir.';it = 'È possibile modificare i conti mastro solo per i punti vendita al dettaglio e metodo dell''inventario (RIM).';de = 'Sie können die Hauptbuch-Konten nur für POS mit der Inventurmethode (Einzelhandel) bearbeiten.'"));
	EndIf;

EndProcedure

&AtClient
Procedure GLAccountInRetailOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountInRetail) Then
		GLAccountInRetail = GetDefaultGLAccount("Inventory");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure MarkupGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(MarkupGLAccount) Then
		MarkupGLAccount = GetDefaultGLAccount("RetailMarkup");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
