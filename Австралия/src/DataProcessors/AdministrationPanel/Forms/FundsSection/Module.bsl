
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
		
		MessageText = NStr("en = 'You cannot disable ""Cash flow projection"" once used.'; ru = '?????????? ???????????? ?????????????????????????? ???? ???? ???????????? ?????????????????? ""???????????????????????? ??????"".';pl = 'Po u??yciu nie mo??esz wy????czy?? ""Preliminarz p??atno??ci"".';es_ES = 'No se puede desactivar la ""Proyecci??n de flujo de efectivo"" una vez utilizada.';es_CO = 'No se puede desactivar la ""Proyecci??n de flujo de efectivo"" una vez utilizada.';tr = '""Nakit ak?????? projeksiyonu"" kullan??ld??ktan sonra devre d?????? b??rak??lamaz.';it = 'Non potete disabilitare la ""Proiezione flusso di cassa"" una volta usato.';de = 'Sie k??nnen den einmal verwendeten Vorgang von ""Cashflow-Projektion"" nicht deaktivieren.'");
		
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
		MessageText = NStr("en = 'Cannot clear this check box. Bank transactions with bank fees are already registered.'; ru = '???? ?????????????? ?????????? ???????? ????????????. ???????????????????? ???????????????? ?? ?????????????????????? ???????????????????? ?????? ????????????????????????????????.';pl = 'Nie mo??na oczy??ci?? tego pola wyboru. Transakcje bankowe z prowizjami bankowymi s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar esta casilla de verificaci??n. Las transacciones bancarias con las comisiones bancarias ya est??n registradas.';es_CO = 'No se puede desmarcar esta casilla de verificaci??n. Las transacciones bancarias con las comisiones bancarias ya est??n registradas.';tr = 'Bu onay kutusu temizlenemiyor. Banka masrafl?? banka i??lemleri kaydedildi.';it = 'Impossibile deselezionare questa casella di controllo. Le transazioni bancarie con commissioni bancarie sono gi?? state registrate.';de = 'Dieses Kontrollk??stchen kann nicht deaktiviert werden. Bankvorg??nge mit Bankgeb??hren sind bereits registriert.'");
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
		
		MessageText = NStr("en = 'The option cannot be disabled unless all ""Bank reconciliation"" documents are deleted.'; ru = '?????????? ???? ?????????? ???????? ?????????????????? ???? ???????????????? ???????? ???????????????????? ""?????????????????????????? ?? ????????????"".';pl = 'Opcja nie mo??e by?? od????czona dop??ki wszystkie dokumenty ""Uzgodnienie banku"" nie b??d?? usuni??te.';es_ES = 'La opci??n no se puede desactivar a menos que se eliminen todos los documentos de ""Conciliaci??n bancaria"".';es_CO = 'La opci??n no se puede desactivar a menos que se eliminen todos los documentos de ""Conciliaci??n bancaria"".';tr = 'T??m ""Banka mutabakat??"" belgeleri silinmedi??i s??rece bu se??enek devre d?????? b??rak??lamaz.';it = 'Questa opzione pu?? essere disabilitata nel caso in cui tutti i documenti ""Riconciliazione bancaria"" siano eliminati.';de = 'Die Option kann nicht deaktiviert werden, es sei denn, es werden alle Belege der ""Bankabstimmung"" gel??scht.'");
		
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
		
		MessageText = NStr("en = 'This option cannot be disabled while there are ""Sales invoices"" with the third-party payment feature.'; ru = '?????? ?????????? ???????????? ??????????????????, ???????? ?????????????? ?????????????? ?????????????????????? ?? ???????????????????? ???????????????? ???????????????????? ??????????????.';pl = 'Ta opcje nie mo??e by?? wy????czona gdy istniej?? ""Faktury sprzeda??y"" z funkcj?? p??atno??ci strony trzeciej.';es_ES = 'Esta opci??n no se puede desactivar mientras existan ""Facturas de venta"" con la funci??n de pago a terceros.';es_CO = 'Esta opci??n no se puede desactivar mientras existan ""Facturas de venta"" con la funci??n de pago a terceros.';tr = '??????nc?? taraf ??deme ??zelli??inde ""Sat???? faturalar??"" oldu??u s??rece bu se??enek devre d?????? b??rak??lamaz.';it = 'Questa opzione non pu?? essere disattivata mentre vi sono ""Fatture di vendita"" con caratteristica di pagamento di terzi.';de = 'Diese Option kann nicht deaktiviert werden, denn es gibt ""Verkaufsrechnungen"" mit der Drittzahlungscharakteristik.'");
		
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
		
		MessageText = NStr("en = 'Cannot clear the ""Allow negative balance"" checkbox. A negative balance is already allowed for certain bank accounts.'; ru = '???? ?????????????? ?????????? ???????????? ""?????????????????? ?????????????????????????? ??????????????"". ?????????????????????????? ?????????????? ?????? ???????????????? ?????? ?????????????????? ???????????????????? ????????????.';pl = 'Nie mo??na wyczy??ci?? pola wyboru ""Zezwalaj saldo ujemne"". Saldo ujemne jest ju?? dozwolone dla okre??lonych rachunk??w bankowych.';es_ES = 'No se puede desmarcar la casilla de verificaci??n ""Permitir un saldo negativo"". Ya se permite un saldo negativo en determinadas cuentas bancarias.';es_CO = 'No se puede desmarcar la casilla de verificaci??n ""Permitir un saldo negativo"". Ya se permite un saldo negativo en determinadas cuentas bancarias.';tr = '""Eksi bakiyeye izin ver"" onay kutusu temizlenemiyor. Eksi bakiyeye izin verilmi?? baz?? banka hesaplar?? mevcut.';it = 'Impossibile deselezionare la casella di controllo ""Permettere saldo negativo"". Un bilancio negativo ?? gi?? concesso per determinati conti corrente.';de = 'Das Kontrollk??stchen ""Negativen Saldo gestatten"" darf nicht deaktiviert werden. Ein negativer Saldo ist bereit f??r bestimmte Bankkonten gestattet.'");
		
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
		MessageText = NStr("en = 'Cannot clear the ""Use overdraft"" checkbox. The overdraft settings are already applied to some bank accounts.'; ru = '???? ?????????????? ?????????? ???????????? ""???????????????????????? ??????????????????"". ?????????????????? ???????????????????? ?????? ?????????????????????? ?? ?????????????????? ???????????????????? ????????????.';pl = 'Nie mo??na odznaczy?? pola ""U??ywaj przekroczenia stanu rachunku"". Ustawienia ustawie?? przekroczenia stanu rachunku s?? zastosowane dla kilku rachunk??w bankowych.';es_ES = 'No se puede desmarcar la casilla de verificaci??n "" Utilizar el sobregiro "". Los ajustes de sobregiro ya se aplican a algunas cuentas bancarias.';es_CO = 'No se puede desmarcar la casilla de verificaci??n "" Utilizar el sobregiro "". Los ajustes de sobregiro ya se aplican a algunas cuentas bancarias.';tr = '""Fazla para ??ekme kullan"" onay kutusu temizlenemiyor. Fazla para ??ekme ayarlar?? baz?? banka hesaplar??na zaten uygulanm???? durumda.';it = 'Impossibile deselezionare la casella di controllo ""Utilizzare scoperto"". Le impostazioni di scoperto sono gi?? applicate ad alcuni conti corrente.';de = 'Fehler beim Deaktivieren des Kontrollk??stchen ""Konto??berziehung verwenden"". Die Einstellungen von Konto??berziehung sind f??r mehrere Bankkonten bereits verwenden.'");
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
		MessageText = NStr("en = 'Bank reconciliation register entries generation'; ru = '???????????????? ?????????????? ???????????????? ???????????????????????????? ?? ????????????';pl = 'Generacja wpis??w rejestru uzgodnienia bankowego';es_ES = 'Se generar??n las entradas de diario del registro de conciliaci??n bancaria';es_CO = 'Se generar??n las entradas del registro de conciliaci??n bancaria';tr = 'Banka mutabakat?? sicil kay??tlar?? giri??i olu??turma';it = 'Generazioni inserimenti registro riconciliazioni bancarie';de = 'Erstellung von Bankabstimmungsregistereintr??gen'");
	Else
		MessageText = NStr("en = 'Bank reconciliation register entries deletion'; ru = '???????????????? ?????????????? ???????????????? ???????????????????????????? ?? ????????????';pl = 'Usuni??cie wpis??w rejestru uzgodnienia bankowego';es_ES = 'Se borrar??n las entradas de diario del registro de conciliaci??n bancaria';es_CO = 'Se borrar??n las entradas del registro de conciliaci??n bancaria';tr = 'Banka mutabakat?? sicil kay??tlar?? giri??i silme';it = 'Eliminazione inserimenti registro riconciliazioni bancarie';de = 'L??schung von Bankabstimmungsregistereintr??gen'");
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
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Bank receipts with operation ""Payout from payment processor"" are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ?????????????????????? ???? ???????? ?? ?????????????????? ""?????????????? ?????????????????? ??????????????"" ?????? ????????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Potwierdzenia zap??aty z operacj?? ""Wyp??ata od systemu p??atno??ci"" s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. Los recibos bancarios con la operaci??n ""Pago desde el procesador de pagos"" ya est??n registrados.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. Los recibos bancarios con la operaci??n ""Pago desde el procesador de pagos"" ya est??n registrados.';tr = 'Onay kutusu temizlenemiyor. ""??deme i??lemcisinden gelen ??deme"" i??lemli, kay??tl?? banka tahsilatlar?? var.';it = 'Impossibile deselezionare la casella di controllo. Le ricevute bancarie con operazione ""Pagamento da elaboratore pagamenti"" sono gi?? state registrate.';de = 'Das Kontrollk??stchen kann nicht deaktiviert werden. Eing??nge mit der Operation ""Auszahlung vom Zahlungsanbieter"" sind bereits registriert.'");
		
	ElsIf Not Results[1].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Online payments are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ????????????-?????????????? ?????? ????????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. P??atno??ci online s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. Los pagos en l??nea ya est??n registrados.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. Los pagos en l??nea ya est??n registrados.';tr = 'Onay kutusu temizlenemiyor. Kay??tl?? ??evrimi??i ??demeler var.';it = 'Impossibile deselezionare la casella di controllo. I pagamenti online sono gi?? stati registrati.';de = 'Das Kontrollk??stchen kann nicht deaktiviert werden. Online-??berweisungen sind bereits registriert.'");
		
	ElsIf Not Results[2].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Online receipts are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ????????????-???????? ?????? ????????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Paragony online s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. Los recibos en l??nea ya est??n registrados.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. Los recibos en l??nea ya est??n registrados.';tr = 'Onay kutusu temizlenemiyor. Kay??tl?? ??evrimi??i tahsilatlar var.';it = 'Impossibile deselezionare la casella di controllo. Le ricevute online sono gi?? state registrate.';de = 'Das Kontrollk??stchen kann nicht deaktiviert werden. Onlinebelege sind bereits registriert.'");
		
	ElsIf Not Results[3].IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. POS terminals with type ""Online payments"" are already registered.'; ru = '???? ?????????????? ?????????? ????????????. ?????????????????????????? ?????????????????? ?? ?????????? ""????????????-??????????????"" ?????? ????????????????????????????????.';pl = 'Nie mo??na wyczy??ci?? tego pola wyboru. Terminale POS z typem ""P??atno??ci online"" s?? ju?? zarejestrowane.';es_ES = 'No se puede desmarcar la casilla de verificaci??n. Los terminales TPV con el tipo ""Pagos en l??nea"" ya est??n registrados.';es_CO = 'No se puede desmarcar la casilla de verificaci??n. Los terminales TPV con el tipo ""Pagos en l??nea"" ya est??n registrados.';tr = 'Onay kutusu temizlenemiyor. ""??evrimi??i ??demeler"" t??r??nde, kay??tl?? POS terminalleri var.';it = 'Impossibile deselezionare la casella di controllo. I terminali POS con tipo ""Pagamenti online"" sono gi?? stati registrati.';de = 'Das Kontrollk??stchen kann nicht deaktiviert werden. POS-Terminals mit dem Typ ""Online-??berweisungen"" sind bereits registriert.'");
		
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