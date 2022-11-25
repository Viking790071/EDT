
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"ExchangeRateDifferencesCalculationFrequencyFO",
			"Visible",
			ConstantsSet.ForeignExchangeAccounting);
		CommonClientServer.SetFormItemProperty(Items,
			"ForeignExchangeGroup",
			"Visible",
			ConstantsSet.ForeignExchangeAccounting);
		
	EndIf;
	
	If AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items,
			"AllowNegativeBalance",
			"Enabled",
			Constants.CheckStockBalanceOnPosting.Get());
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" Then
		
		ConstantsSet.ForeignExchangeAccounting = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UsePaymentCalendar" Then
		
		ConstantsSet.UsePaymentCalendar = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseBankReconciliation" Then
		
		ConstantsSet.UseBankReconciliation = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseThirdPartyPayment" Then
		
		ConstantsSet.UseThirdPartyPayment = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UsePaymentProcessors" Then
		
		ConstantsSet.UsePaymentProcessors = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseBankCharges" Then
		
		ConstantsSet.UseBankCharges = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AllowNegativeBalance" Then
		
		ConstantsSet.AllowNegativeBalance = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseOverdraft" Then
		
		ConstantsSet.UseOverdraft = CurrentValue;
		
	EndIf;
	
EndProcedure

// Check on the possibility to disable the option ForeignExchangeAccounting.
//
&AtServer
Function CancellationUncheckForeignExchangeAccounting()
	
	MessageText = DataProcessors.AdministrationPanel.CancellationUncheckForeignExchangeAccounting();
	
	Return MessageText;
	
EndFunction

// Check on the possibility to disable the option UsePaymentCalendar.
//
&AtServer
Function CancellationUncheckUsePaymentCalendar()
	
	MessageText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS CheckField
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'You cannot disable ""Cash flow projection"" once used.'; ru = 'После начала использования вы не можете отключить ""Планирование ДДС"".';pl = 'Po użyciu nie możesz wyłączyć ""Preliminarz płatności"".';es_ES = 'No se puede desactivar la ""Proyección de flujo de efectivo"" una vez utilizada.';es_CO = 'No se puede desactivar la ""Proyección de flujo de efectivo"" una vez utilizada.';tr = '""Nakit akışı projeksiyonu"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare la ""Proiezione flusso di cassa"" una volta usato.';de = 'Sie können den einmal verwendeten Vorgang von ""Cashflow-Projektion"" nicht deaktivieren.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

&AtServer
Function CancellationUncheckUseBankCharges()
	
	MessageText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS CheckField
	|FROM
	|	AccumulationRegister.BankCharges AS BankCharges";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		MessageText = NStr("en = 'Cannot clear this check box. Bank transactions with bank fees are already registered.'; ru = 'Не удается снять этот флажок. Банковские операции с банковскими комиссиями уже зарегистрированы.';pl = 'Nie można oczyścić tego pola wyboru. Transakcje bankowe z prowizjami bankowymi są już zarejestrowane.';es_ES = 'No se puede desmarcar esta casilla de verificación. Las transacciones bancarias con las comisiones bancarias ya están registradas.';es_CO = 'No se puede desmarcar esta casilla de verificación. Las transacciones bancarias con las comisiones bancarias ya están registradas.';tr = 'Bu onay kutusu temizlenemiyor. Banka masraflı banka işlemleri kaydedildi.';it = 'Impossibile deselezionare questa casella di controllo. Le transazioni bancarie con commissioni bancarie sono già state registrate.';de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Bankvorgänge mit Bankgebühren sind bereits registriert.'");
	EndIf;
	
	Return MessageText;
	
EndFunction

&AtServer
Function CancellationUncheckUseBankReconciliation()
	
	MessageText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS CheckField
	|FROM
	|	AccumulationRegister.BankReconciliation AS BankReconciliation
	|WHERE
	|	BankReconciliation.RecordType = VALUE(AccumulationRecordType.Expense)";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'The option cannot be disabled unless all ""Bank reconciliation"" documents are deleted.'; ru = 'Опция не может быть отключена до удаления всех документов ""Взаиморасчеты с банком"".';pl = 'Opcja nie może być odłączona dopóki wszystkie dokumenty ""Uzgodnienie banku"" nie będą usunięte.';es_ES = 'La opción no se puede desactivar a menos que se eliminen todos los documentos de ""Conciliación bancaria"".';es_CO = 'La opción no se puede desactivar a menos que se eliminen todos los documentos de ""Conciliación bancaria"".';tr = 'Tüm ""Banka mutabakatı"" belgeleri silinmediği sürece bu seçenek devre dışı bırakılamaz.';it = 'Questa opzione può essere disabilitata nel caso in cui tutti i documenti ""Riconciliazione bancaria"" siano eliminati.';de = 'Die Option kann nicht deaktiviert werden, es sei denn, es werden alle Belege der ""Bankabstimmung"" gelöscht.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

&AtServer
Function CancellationUncheckUseThirdPartyPayment()
	
	MessageText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS CheckField
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.ThirdPartyPayment";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'This option cannot be disabled while there are ""Sales invoices"" with the third-party payment feature.'; ru = 'Эту опцию нельзя отключить, пока имеются инвойсы покупателям с включенной функцией стороннего платежа.';pl = 'Ta opcje nie może być wyłączona gdy istnieją ""Faktury sprzedaży"" z funkcją płatności strony trzeciej.';es_ES = 'Esta opción no se puede desactivar mientras existan ""Facturas de venta"" con la función de pago a terceros.';es_CO = 'Esta opción no se puede desactivar mientras existan ""Facturas de venta"" con la función de pago a terceros.';tr = 'Üçüncü taraf ödeme özelliğinde ""Satış faturaları"" olduğu sürece bu seçenek devre dışı bırakılamaz.';it = 'Questa opzione non può essere disattivata mentre vi sono ""Fatture di vendita"" con caratteristica di pagamento di terzi.';de = 'Diese Option kann nicht deaktiviert werden, denn es gibt ""Verkaufsrechnungen"" mit der Drittzahlungscharakteristik.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

&AtServer
Function CancellationUncheckAllowNegativeBalance()
	
	MessageText = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE AS CheckField
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	BankAccounts.AllowNegativeBalance";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		MessageText = NStr("en = 'Cannot clear the ""Allow negative balance"" checkbox. A negative balance is already allowed for certain bank accounts.'; ru = 'Не удалось снять флажок ""Разрешить отрицательный остаток"". Отрицательный остаток уже разрешен для некоторых банковских счетов.';pl = 'Nie można wyczyścić pola wyboru ""Zezwalaj saldo ujemne"". Saldo ujemne jest już dozwolone dla określonych rachunków bankowych.';es_ES = 'No se puede desmarcar la casilla de verificación ""Permitir un saldo negativo"". Ya se permite un saldo negativo en determinadas cuentas bancarias.';es_CO = 'No se puede desmarcar la casilla de verificación ""Permitir un saldo negativo"". Ya se permite un saldo negativo en determinadas cuentas bancarias.';tr = '""Eksi bakiyeye izin ver"" onay kutusu temizlenemiyor. Eksi bakiyeye izin verilmiş bazı banka hesapları mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Permettere saldo negativo"". Un bilancio negativo è già concesso per determinati conti corrente.';de = 'Das Kontrollkästchen ""Negativen Saldo gestatten"" darf nicht deaktiviert werden. Ein negativer Saldo ist bereit für bestimmte Bankkonten gestattet.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

&AtServer
Function CancellationUncheckUseOverdraft()
	
	MessageText = "";
	
	IsOverdraftUsed = IsOverdraftUsed();
	If Not IsOverdraftUsed Then
		
		Query = New Query;
		Query.Text = "SELECT TOP 1
		|	BankAccounts.Ref AS Ref
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.UseOverdraft
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	BankAccounts.Ref
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|		INNER JOIN InformationRegister.OverdraftLimits AS OverdraftLimits
		|		ON BankAccounts.Ref = OverdraftLimits.BankAccount";
		
		QueryResult = Query.Execute();
		IsOverdraftUsed = Not QueryResult.IsEmpty();
		
	EndIf;
	
	If IsOverdraftUsed Then
		MessageText = NStr("en = 'Cannot clear the ""Use overdraft"" checkbox. The overdraft settings are already applied to some bank accounts.'; ru = 'Не удалось снять флажок ""Использовать овердрафт"". Настройки овердрафта уже применяются к некоторым банковским счетам.';pl = 'Nie można odznaczyć pola ""Używaj przekroczenia stanu rachunku"". Ustawienia ustawień przekroczenia stanu rachunku są zastosowane dla kilku rachunków bankowych.';es_ES = 'No se puede desmarcar la casilla de verificación "" Utilizar el sobregiro "". Los ajustes de sobregiro ya se aplican a algunas cuentas bancarias.';es_CO = 'No se puede desmarcar la casilla de verificación "" Utilizar el sobregiro "". Los ajustes de sobregiro ya se aplican a algunas cuentas bancarias.';tr = '""Fazla para çekme kullan"" onay kutusu temizlenemiyor. Fazla para çekme ayarları bazı banka hesaplarına zaten uygulanmış durumda.';it = 'Impossibile deselezionare la casella di controllo ""Utilizzare scoperto"". Le impostazioni di scoperto sono già applicate ad alcuni conti corrente.';de = 'Fehler beim Deaktivieren des Kontrollkästchen ""Kontoüberziehung verwenden"". Die Einstellungen von Kontoüberziehung sind für mehrere Bankkonten bereits verwenden.'");
	EndIf;
	
	Return MessageText;
	
EndFunction

Function IsOverdraftUsed()
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	OverdraftLimitsSliceLast.BankAccount AS BankAccount,
	|	OverdraftLimitsSliceLast.StartDate AS StartDate,
	|	CASE
	|		WHEN OverdraftLimitsSliceLast.EndDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(3999, 12, 31, 23, 59, 59)
	|		ELSE OverdraftLimitsSliceLast.EndDate
	|	END AS EndDate
	|INTO TT_Overdrafts
	|FROM
	|	InformationRegister.OverdraftLimits.SliceLast AS OverdraftLimitsSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	TT_Overdrafts.BankAccount AS BankAccount
	|FROM
	|	TT_Overdrafts AS TT_Overdrafts
	|		INNER JOIN AccumulationRegister.CashAssets.BalanceAndTurnovers(
	|				,
	|				,
	|				Record,
	|				,
	|				BankAccountPettyCash IN
	|					(SELECT DISTINCT
	|						TT_Overdrafts.BankAccount
	|					FROM
	|						TT_Overdrafts AS TT_Overdrafts)) AS CashAssetsBalanceAndTurnovers
	|		ON TT_Overdrafts.BankAccount = CashAssetsBalanceAndTurnovers.BankAccountPettyCash
	|			AND TT_Overdrafts.StartDate <= CashAssetsBalanceAndTurnovers.Period
	|			AND TT_Overdrafts.EndDate >= CashAssetsBalanceAndTurnovers.Period
	|			AND (CashAssetsBalanceAndTurnovers.AmountCurClosingBalance < 0)";
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are catalog items "Currencies" except the predefined, it is not allowed to clear the
	// ForeignExchangeAccounting check box
	If AttributePathToData = "ConstantsSet.ForeignExchangeAccounting" Then
		
		If Constants.ForeignExchangeAccounting.Get() <> ConstantsSet.ForeignExchangeAccounting 
			AND (NOT ConstantsSet.ForeignExchangeAccounting) Then
			
			ErrorText = CancellationUncheckForeignExchangeAccounting();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
	
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UsePaymentCalendar" Then
		
		If Constants.UsePaymentCalendar.Get() <> ConstantsSet.UsePaymentCalendar
			AND NOT ConstantsSet.UsePaymentCalendar Then
			
			ErrorText = CancellationUncheckUsePaymentCalendar();
			
			If NOT IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseBankReconciliation" Then
		
		If Constants.UseBankReconciliation.Get() <> ConstantsSet.UseBankReconciliation Then
			
			ErrorText = CancellationUncheckUseBankReconciliation();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Constants.UseBankReconciliation.Get());
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseThirdPartyPayment" Then
		
		If Constants.UseThirdPartyPayment.Get() <> ConstantsSet.UseThirdPartyPayment
			And Not ConstantsSet.UseThirdPartyPayment Then
			
			ErrorText = CancellationUncheckUseThirdPartyPayment();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UsePaymentProcessors" Then
		
		If Constants.UsePaymentProcessors.Get() <> ConstantsSet.UsePaymentProcessors
			And Not ConstantsSet.UsePaymentProcessors Then
			
			ErrorText = CancellationUncheckUsePaymentProcessors();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseBankCharges" Then
		
		If Constants.UseBankCharges.Get() <> ConstantsSet.UseBankCharges
			And Not ConstantsSet.UseBankCharges Then
			
			ErrorText = CancellationUncheckUseBankCharges();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.AllowNegativeBalance" Then
		
		If Constants.AllowNegativeBalance.Get() <> ConstantsSet.AllowNegativeBalance
			And Not ConstantsSet.AllowNegativeBalance Then
			
			ErrorText = CancellationUncheckAllowNegativeBalance();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseOverdraft" Then
		
		If Constants.UseOverdraft.Get() <> ConstantsSet.UseOverdraft
			And Not ConstantsSet.UseOverdraft Then
			
			ErrorText = CancellationUncheckUseOverdraft();
			
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure GenerateOrDeleteBankReconciliationRegisterEntries()
	
	TimeConsumingOperation = GenerateOrDeleteBankReconciliationRegisterEntriesAtServer();
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = TimeConsumingOperation.MessageText;
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, , IdleParameters);
	
EndProcedure

&AtServer
Function GenerateOrDeleteBankReconciliationRegisterEntriesAtServer()
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("UseBankReconciliation", ConstantsSet.UseBankReconciliation);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	If ProcedureParameters.UseBankReconciliation Then
		MessageText = NStr("en = 'Bank reconciliation register entries generation'; ru = 'Создание записей регистра взаиморасчетов с банком';pl = 'Generacja wpisów rejestru uzgodnienia bankowego';es_ES = 'Se generarán las entradas de diario del registro de conciliación bancaria';es_CO = 'Se generarán las entradas del registro de conciliación bancaria';tr = 'Banka mutabakatı sicil kayıtları girişi oluşturma';it = 'Generazioni inserimenti registro riconciliazioni bancarie';de = 'Erstellung von Bankabstimmungsregistereinträgen'");
	Else
		MessageText = NStr("en = 'Bank reconciliation register entries deletion'; ru = 'Удаление записей регистра взаиморасчетов с банком';pl = 'Usunięcie wpisów rejestru uzgodnienia bankowego';es_ES = 'Se borrarán las entradas de diario del registro de conciliación bancaria';es_CO = 'Se borrarán las entradas del registro de conciliación bancaria';tr = 'Banka mutabakatı sicil kayıtları girişi silme';it = 'Eliminazione inserimenti registro riconciliazioni bancarie';de = 'Löschung von Bankabstimmungsregistereinträgen'");
	EndIf;
	ExecutionParameters.BackgroundJobDescription = MessageText;
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		"AccumulationRegisters.BankReconciliation.GenerateOrDeleteRecordsOnChangingFunctionalOption",
		ProcedureParameters,
		ExecutionParameters);
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

#EndRegion

&AtServer
Function CancellationUncheckUsePaymentProcessors()
	
	MessageText = "";
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	PaymentReceipt.Ref AS Ref
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|WHERE
	|	PaymentReceipt.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OnlinePayment.Ref AS Ref
	|FROM
	|	Document.OnlinePayment AS OnlinePayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OnlineReceipt.Ref AS Ref
	|FROM
	|	Document.OnlineReceipt AS OnlineReceipt
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	POSTerminals.Ref AS Ref
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments)";
	
	Results = Query.ExecuteBatch();
	
	If Not Results[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Bank receipts with operation ""Payout from payment processor"" are already registered.'; ru = 'Не удалось снять флажок. Поступления на счет с операцией ""Выплата платежной системы"" уже зарегистрированы.';pl = 'Nie można wyczyścić tego pola wyboru. Potwierdzenia zapłaty z operacją ""Wypłata od systemu płatności"" są już zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificación. Los recibos bancarios con la operación ""Pago desde el procesador de pagos"" ya están registrados.';es_CO = 'No se puede desmarcar la casilla de verificación. Los recibos bancarios con la operación ""Pago desde el procesador de pagos"" ya están registrados.';tr = 'Onay kutusu temizlenemiyor. ""Ödeme işlemcisinden gelen ödeme"" işlemli, kayıtlı banka tahsilatları var.';it = 'Impossibile deselezionare la casella di controllo. Le ricevute bancarie con operazione ""Pagamento da elaboratore pagamenti"" sono già state registrate.';de = 'Das Kontrollkästchen kann nicht deaktiviert werden. Eingänge mit der Operation ""Auszahlung vom Zahlungsanbieter"" sind bereits registriert.'");
		
	ElsIf Not Results[1].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Online payments are already registered.'; ru = 'Не удалось снять флажок. Онлайн-платежи уже зарегистрированы.';pl = 'Nie można wyczyścić tego pola wyboru. Płatności online są już zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificación. Los pagos en línea ya están registrados.';es_CO = 'No se puede desmarcar la casilla de verificación. Los pagos en línea ya están registrados.';tr = 'Onay kutusu temizlenemiyor. Kayıtlı çevrimiçi ödemeler var.';it = 'Impossibile deselezionare la casella di controllo. I pagamenti online sono già stati registrati.';de = 'Das Kontrollkästchen kann nicht deaktiviert werden. Online-Überweisungen sind bereits registriert.'");
		
	ElsIf Not Results[2].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Online receipts are already registered.'; ru = 'Не удалось снять флажок. Онлайн-чеки уже зарегистрированы.';pl = 'Nie można wyczyścić tego pola wyboru. Paragony online są już zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificación. Los recibos en línea ya están registrados.';es_CO = 'No se puede desmarcar la casilla de verificación. Los recibos en línea ya están registrados.';tr = 'Onay kutusu temizlenemiyor. Kayıtlı çevrimiçi tahsilatlar var.';it = 'Impossibile deselezionare la casella di controllo. Le ricevute online sono già state registrate.';de = 'Das Kontrollkästchen kann nicht deaktiviert werden. Onlinebelege sind bereits registriert.'");
		
	ElsIf Not Results[3].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. POS terminals with type ""Online payments"" are already registered.'; ru = 'Не удалось снять флажок. Эквайринговые терминалы с типом ""Онлайн-платежи"" уже зарегистрированы.';pl = 'Nie można wyczyścić tego pola wyboru. Terminale POS z typem ""Płatności online"" są już zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificación. Los terminales TPV con el tipo ""Pagos en línea"" ya están registrados.';es_CO = 'No se puede desmarcar la casilla de verificación. Los terminales TPV con el tipo ""Pagos en línea"" ya están registrados.';tr = 'Onay kutusu temizlenemiyor. ""Çevrimiçi ödemeler"" türünde, kayıtlı POS terminalleri var.';it = 'Impossibile deselezionare la casella di controllo. I terminali POS con tipo ""Pagamenti online"" sono già stati registrati.';de = 'Das Kontrollkästchen kann nicht deaktiviert werden. POS-Terminals mit dem Typ ""Online-Überweisungen"" sind bereits registriert.'");
		
	EndIf;
		
	Return ErrorText;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonCached.ApplicationRunMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "CheckStockBalanceOnPosting" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"AllowNegativeBalance",
				"Enabled",
				Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the ForeignExchangeAccounting field.
//
&AtClient
Procedure FunctionalCurrencyTransactionsAccountingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the FunctionalCurrency field.
//
&AtClient
Procedure NationalCurrencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - click reference handler ForeignCurrencyRevaluationPeriodicity.
//
&AtClient
Procedure ExchangeRateDifferencesCalculationFrequencyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the SetOffAdvancePaymentsAutomatically field.
//
&AtClient
Procedure RegistrateDebtsAdvancesAutomaticallyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UsePaymentCalendar field.
//
&AtClient
Procedure FunctionalOptionPaymentCalendarOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseBankChargesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseBankReconciliationOnChange(Item)
	
	RefreshingInterface = True;
	
	Attachable_OnAttributeChange(Item, RefreshingInterface);
	
	If RefreshingInterface Then
		GenerateOrDeleteBankReconciliationRegisterEntries();
	EndIf;
	
EndProcedure

&AtClient
Procedure UseThirdPartyPaymentOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure AllowNegativeBalanceOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UsePaymentProcessorsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseOverdraftOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion