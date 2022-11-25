#Region Variables

&AtClient
Var InitialValues;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.Period = Date(1,1,1) Then
		Record.Period = CurrentSessionDate();
	EndIf;
	
	If Parameters.FillingValues.Property("BankAccount") Then
		Record.Company = Common.ObjectAttributeValue(Parameters.FillingValues.BankAccount, "Owner");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(Record.StartDate) Then
		InitialValues = RecordStructure();
		FillPropertyValues(InitialValues, Record);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Record.StartDate = Date(1,1,1) Then
		Cancel = True;
		CommonClientServer.MessageToUser(NStr("en = '""Start date"" is required field.'; ru = 'Поле ""Дата начала"" не заполнено.';pl = '""Data rozpoczęcia"" to jest wymagane pole.';es_ES = 'La ""fecha de inicio"" es un campo obligatorio.';es_CO = 'La ""fecha de inicio"" es un campo obligatorio.';tr = '""Başlangıç tarihi"" gerekli alandır.';it = '""Data di avvio"" è un campo richiesto.';de = '""Startdatum"" ist ein Pflichtfeld.'"),, "Record.StartDate");
	EndIf;
	
	If Not Cancel And BegOfDay(Record.EndDate) <> Date(1,1,1) And Record.StartDate > Record.EndDate Then
		Cancel = True;
		CommonClientServer.MessageToUser(NStr("en = '""Start date"" cannot be later than ""End date"".'; ru = 'Дата начала не может быть позже даты окончания.';pl = '""Data rozpoczęcia"" nie może być późniejsza niż ""Data zakończenia"".';es_ES = 'La ""Fecha de inicio"" no puede ser posterior a la ""Fecha final"".';es_CO = 'La ""Fecha de inicio"" no puede ser posterior a la ""Fecha final"".';tr = '""Başlangıç tarihi"" ""Bitiş tarihi""nden sonra olamaz.';it = '""Data di avvio"" non può essere successivo a ""Data di fine""';de = '""Startdatum"" darf nicht über ""Enddatum"" liegen.'"),, "Record.StartDate");
	EndIf;
	
	If Not Cancel And BegOfDay(Record.EndDate) <> Date(1,1,1) Then
		Record.EndDate = EndOfDay(Record.EndDate);
	EndIf;
	
	CheckAnotherEntryForPeriod(Cancel);
	
	If Not Cancel And Not AllowNegativeBalance(Record.BankAccount) Then
		RecordStructure = RecordStructure();
		FillPropertyValues(RecordStructure, Record);
		
		ActualBalance = GetActualBalance(Record.StartDate, Record.BankAccount);
		
		If (-ActualBalance > Record.Limit) 
			Or (InitialValues = Undefined And IsLimitLessNegativeBalance(RecordStructure)) Then
			
			MessageText = NStr( "en = 'Cannot save the changes.
				|The new overdraft limit is less than the overdraft amount already recorded.'; 
				|ru = 'Не удалось сохранить изменения.
				|Новый лимит овердрафта меньше уже зарегистрированной суммы овердрафта.';
				|pl = 'Nie można zapisać zmian.
				|Nowy limit przekroczenia stanu rachunku jest mniejszy niż już zapisana kwota przekroczenia stanu rachunku.';
				|es_ES = 'No se pueden guardar los cambios.
				| El nuevo límite de sobregiro es inferior al importe de sobregiro ya registrado.';
				|es_CO = 'No se pueden guardar los cambios.
				| El nuevo límite de sobregiro es inferior al importe de sobregiro ya registrado.';
				|tr = 'Değişiklikler kaydedilemiyor.
				|Yeni fazla para çekme limiti zaten kayıtlı olan fazla para çekme tutarından düşük.';
				|it = 'Impossibile salvare le modifiche.
				|Il nuovo limite scoperto è inferiore dell''importo di scoperto già registrato.';
				|de = 'Fehler beim Speichern von Änderungen.
				|Die neue Überziehungsgrenze liegt unter der bereits gebuchten Kontoüberziehung.'");
			CommonClientServer.MessageToUser(MessageText,,,,Cancel);
			
		ElsIf InitialValues <> Undefined Then
			
			CheckOverdraftUsed(InitialValues, RecordStructure, Cancel);
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetActualBalance(StartDate, BankAccount)
	
	AmountCurBalance = 0;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	CashAssetsBalance.AmountCurBalance AS AmountCurBalance
	|FROM
	|	AccumulationRegister.CashAssets.Balance(&StartDate, BankAccountPettyCash = &BankAccount) AS CashAssetsBalance";
	
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("BankAccount", BankAccount);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		AmountCurBalance = Selection.AmountCurBalance;
	EndIf;
	
	Return AmountCurBalance;
	
EndFunction

&AtClient
Function RecordStructure()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Company");
	RecordStructure.Insert("BankAccount");
	RecordStructure.Insert("StartDate", Date(1,1,1));
	RecordStructure.Insert("EndDate", Date(1,1,1));
	RecordStructure.Insert("Limit", 0);
	
	Return RecordStructure;
	
EndFunction

&AtServer
Procedure CheckAnotherEntryForPeriod(Cancel)
	
	If Cancel Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	OverdraftLimits.StartDate AS StartDate,
	|	CASE
	|		WHEN OverdraftLimits.EndDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(3999, 12, 31, 23, 59, 59)
	|		ELSE OverdraftLimits.EndDate
	|	END AS EndDate
	|INTO TT_Temp
	|FROM
	|	InformationRegister.OverdraftLimits AS OverdraftLimits
	|WHERE
	|	OverdraftLimits.Company = &Company
	|	AND OverdraftLimits.BankAccount = &BankAccount
	|	AND OverdraftLimits.Period <> &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	1 AS Field,
	|	TT_Temp.StartDate AS StartDate,
	|	TT_Temp.EndDate AS EndDate
	|FROM
	|	TT_Temp AS TT_Temp
	|WHERE
	|	TT_Temp.StartDate BETWEEN &StartDate AND &EndDate
	|	AND TT_Temp.EndDate BETWEEN &StartDate AND &EndDate
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TT_Temp.StartDate,
	|	TT_Temp.EndDate
	|FROM
	|	TT_Temp AS TT_Temp
	|WHERE
	|	TT_Temp.StartDate <= &StartDate
	|	AND TT_Temp.EndDate >= &EndDate
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TT_Temp.StartDate,
	|	TT_Temp.EndDate
	|FROM
	|	TT_Temp AS TT_Temp
	|WHERE
	|	TT_Temp.StartDate <= &StartDate
	|	AND TT_Temp.EndDate BETWEEN &StartDate AND &EndDate
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TT_Temp.StartDate,
	|	TT_Temp.EndDate
	|FROM
	|	TT_Temp AS TT_Temp
	|WHERE
	|	TT_Temp.StartDate BETWEEN &StartDate AND &EndDate
	|	AND TT_Temp.EndDate >= &EndDate";
	
	Query.SetParameter("Company", Record.Company);
	Query.SetParameter("BankAccount", Record.BankAccount);
	Query.SetParameter("Period", Record.Period);
	Query.SetParameter("StartDate", Record.StartDate);
	Query.SetParameter("EndDate", ?(Record.EndDate=Date(1,1,1), Date(3999,12,31), Record.EndDate));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		PeriodStr = StringFunctionsClientServer.SubstituteParametersToString(
			"%1 - %2",
			Format(Selection.StartDate, "DLF=D"),
			?(Selection.EndDate=Date(3999,12,31,23,59,59), "...", Format(Selection.EndDate, "DLF=D")));
			
		If Selection.Field = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the changes. An overdraft limit is already recorded in the period %1.'; ru = 'Не удалось сохранить изменения. Лимит овердрафта уже зарегистрирован в периоде %1.';pl = 'Nie można zapisać zmian. Limit przekroczenia stanu rachunku jest już zapisany w okresie %1.';es_ES = 'No se pueden guardar los cambios. Ya se ha registrado un límite de sobregiro en el periodo %1.';es_CO = 'No se pueden guardar los cambios. Ya se ha registrado un límite de sobregiro en el periodo %1.';tr = 'Değişiklikler kaydedilemiyor. %1 dönemi için fazla para çekme limiti zaten kayıtlı.';it = 'Impossibile salvare le modifiche. Un limite scoperto è già registrato in questo periodo %1.';de = 'Fehler beim Speichern von Änderungen. Eine Überziehungsgrenze ist für den Zeitraum %1 bereits gebucht.'"),
				PeriodStr);
		ElsIf Selection.Field = 4 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save the changes. End date %1 is within the validity period %2 of the existing overdraft limit.
				|Select another end date.'; 
				|ru = 'Не удалось сохранить изменения. Дата окончания %1 находится в пределах срока действия %2существующего лимита овердрафта.
				|Выберите другую дату окончания.';
				|pl = 'Nie można zapisać zmian. Data zakończenia %1 mieści się w okresie ważności %2 istniejącego limitu przekroczenia stanu rachunku.
				|Wybierz inną datę zakończenia.';
				|es_ES = 'No se pueden guardar los cambios. La fecha final %1está dentro del periodo de validez%2 del límite de sobregiro existente.
				| Seleccione otra fecha final.';
				|es_CO = 'No se pueden guardar los cambios. La fecha final %1está dentro del periodo de validez%2 del límite de sobregiro existente.
				| Seleccione otra fecha final.';
				|tr = 'Değişiklikler kaydedilemiyor. %1 bitiş tarihi, mevcut fazla para çekme limitinin geçerlilik dönemi olan %2 içinde.
				|Başka bir bitiş tarihi seçin.';
				|it = 'Impossibile salvare le modifiche. La data di fine %1 è entro il periodo di validità %2 del limite di scoperto esistente.
				|Selezionare un''altra data di fine.';
				|de = 'Fehler beim Speichern von Änderungen. Enddatum %1 liegt binnen der Gültigkeitsdauer %2 der vorhandenen Überziehungsgrenze.
				|Wählen Sie ein anderes Enddatum aus.'"),
			?(Record.EndDate=Date(1,1,1), "...", Format(Record.EndDate, "DLF=D")),
			PeriodStr);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the changes. Start date %1 is within the validity period %2 of the existing overdraft limit.
					|Select another start date.'; 
					|ru = 'Не удалось сохранить изменения. Дата начала %1 находится в пределах срока действия %2существующего лимита овердрафта.
					|Выберите другую дату начала.';
					|pl = 'Nie można zapisać zmian. Data rozpoczęcia %1 mieści się w okresie ważności %2 istniejącego limitu przekroczenia stanu rachunku.
					|Wybierz inną datę rozpoczęcia.';
					|es_ES = 'No se pueden guardar los cambios. La fecha de inicio %1está dentro del periodo de validez %2del límite de sobregiro existente.
					| Seleccione otra fecha de inicio.';
					|es_CO = 'No se pueden guardar los cambios. La fecha de inicio %1está dentro del periodo de validez %2del límite de sobregiro existente.
					| Seleccione otra fecha de inicio.';
					|tr = 'Değişiklikler kaydedilemiyor. %1 başlangıç tarihi, mevcut fazla para çekme limitinin geçerlilik dönemi olan %2 içinde.
					|Başka bir başlangıç tarihi seçin.';
					|it = 'Impossibile salvare le modifiche. La data di inizio %1 è entro il periodo di validità %2 del limite di scoperto esistente.
					|Selezionare un''altra data di avvio.';
					|de = 'Fehler beim Speichern von Änderungen. Startdatum %1 liegt binnen der Gültigkeitsdauer %2 der vorhandenen Überziehungsgrenze.
					|Wählen Sie ein anderes Startdatum.'"),
				Format(Record.StartDate, "DLF=D"),
				PeriodStr);
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsLimitLessNegativeBalance(Parameters)
	
	Return InformationRegisters.OverdraftLimits.IsOverdraftUsedInPayments(Parameters, True);
	
EndFunction

&AtServerNoContext
Function AllowNegativeBalance(BankAccount)
	
	Return Common.ObjectAttributeValue(BankAccount, "AllowNegativeBalance");
	
EndFunction

&AtServerNoContext
Procedure CheckOverdraftUsed(InitialValues, Record, Cancel)
	
	Parameters = New Structure;
	Parameters.Insert("Company", Record.Company);
	Parameters.Insert("BankAccount", Record.BankAccount);
	Parameters.Insert("Limit", 0);
	
	If InitialValues.StartDate < Record.StartDate Then
		Parameters.Insert("StartDate", InitialValues.StartDate);
		Parameters.Insert("EndDate", Record.StartDate);
		If InformationRegisters.OverdraftLimits.IsOverdraftUsedInPayments(Parameters) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the changes. You are trying to change the Start date from %1 to %2.
					|In period %1 - %2, the bank account has a negative balance. There is no overdraft limit to cover it.'; 
					|ru = 'Не удалось изменить дату начала с %1 на %2.
					|В периоде %2 - %1 на банковском счете имеется отрицательный остаток. Нет лимита овердрафта для его покрытия.';
					|pl = 'Nie można zapisać zmian. Próbujesz zmienić Datę rozpoczęcia z %1 na %2.
					|W okresie %1 - %2, rachunek bankowy ma ujemne saldo. Nie ma limitu przekroczenia stanu rachunku aby pokryć go.';
					|es_ES = 'No se pueden guardar los cambios. Usted está intentando cambiar la fecha de inicio de %1 a %2. 
					|En el período %1- %2, la cuenta bancaria tiene un saldo negativo. No existe un límite de sobregiro para cubrirlo.';
					|es_CO = 'No se pueden guardar los cambios. Usted está intentando cambiar la fecha de inicio de %1 a %2. 
					|En el período %1- %2, la cuenta bancaria tiene un saldo negativo. No existe un límite de sobregiro para cubrirlo.';
					|tr = 'Değişiklikler kaydedilemiyor. %1 olan başlangıç tarihini %2 olarak değiştirmeye çalışıyorsunuz.
					|%1 - %2 döneminde, banka hesabının bakiyesi eksi. Bu tutarı karşılayacak fazla para çekme limiti yok.';
					|it = 'Impossibile salvare le modifiche. Stai provando a modificare la Data di avvio da %1 a %2.
					|Nel periodo %1 - %2, il conto corrente ha saldo negativo. Non vi è limite di scoperto da coprire.';
					|de = 'Fehler beim Speichern von Änderungen. Sie versuchen das Startdatum vom %1 auf %2 zu ändern.
					|Im Zeitraum %1 - %2 hat das Bankkonto einen negativen Saldo. Es gibt keine Überziehungsrenze diesen zu decken.'"),
				Format(InitialValues.StartDate, "DLF=D"),
				Format(Record.StartDate, "DLF=D"));
			CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		EndIf;
	EndIf;
	
	OldEndDate = ?(InitialValues.EndDate=Date(1,1,1), Date(3999,12,31,23,59,59), InitialValues.EndDate);
	NewEndDate = ?(Record.EndDate=Date(1,1,1), Date(3999,12,31,23,59,59), Record.EndDate);
	
	If OldEndDate > NewEndDate Then
		Parameters.Insert("StartDate", NewEndDate);
		Parameters.Insert("EndDate", OldEndDate);
		If InformationRegisters.OverdraftLimits.IsOverdraftUsedInPayments(Parameters) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the changes. You are trying to change the End date from %1 to %2.
					|In period %2 - %1, the bank account has a negative balance. There is no overdraft limit to cover it.'; 
					|ru = 'Не удалось изменить дату окончания с %1 на %2.
					|В периоде %2 - %1 на банковском счете имеется отрицательный остаток. Нет лимита овердрафта для его покрытия.';
					|pl = 'Nie można zapisać zmian. Próbujesz zmienić Datę zakończenia z %1 na %2.
					|W okresie %2 - %1, rachunek bankowy ma ujemne saldo. Nie ma limitu przekroczenia stanu rachunku aby pokryć go.';
					|es_ES = 'No se pueden guardar los cambios. Usted está intentando cambiar la fecha final de %1 a %2. 
					|En el período %2- %1, la cuenta bancaria tiene un saldo negativo. No existe un límite de sobregiro para cubrirlo.';
					|es_CO = 'No se pueden guardar los cambios. Usted está intentando cambiar la fecha final de %1 a %2. 
					|En el período %2- %1, la cuenta bancaria tiene un saldo negativo. No existe un límite de sobregiro para cubrirlo.';
					|tr = 'Değişiklikler kaydedilemiyor. %1 olan bitiş tarihini %2 olarak değiştirmeye çalışıyorsunuz.
					|%2 - %1 döneminde, banka hesabının bakiyesi eksi. Bu tutarı karşılayacak fazla para çekme limiti yok.';
					|it = 'Impossibile salvare le modifiche. Stai provando a modificare la Data di fine da %1 a %2.
					|Nel periodo %2 - %1, il conto corrente ha saldo negativo. Non vi è limite di scoperto da coprire.';
					|de = 'Fehler beim Speichern von Änderungen. Sie versuchen das Enddatum vom %1 auf %2.
					| zu ändern. Im Zeitraum %2 - %1, hat das Bankkonto einen negativen Saldo. Es gibt keine Überziehungsrenze diesen zu decken.'"),
				?(InitialValues.EndDate=Date(1,1,1), "...", Format(InitialValues.EndDate, "DLF=D")),
				?(Record.EndDate=Date(1,1,1), "...", Format(Record.EndDate, "DLF=D")));
			CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		EndIf;
	EndIf;
	
	If InitialValues.Limit > Record.Limit And IsLimitLessNegativeBalance(Record) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the changes. You are trying to change the overdraft limit from %1 to %2.
					|In period %3 - %4, the bank account has a negative balance that is greater than the new overdraft limit.'; 
					|ru = 'Не удалось изменить лимит овердрафта с %1 на %2.
					|В периоде %3 - %4 на банковском счете имеется отрицательный остаток, превышающий новый лимит овердрафта.';
					|pl = 'Nie można zapisać zmian. Próbujesz zmienić limit przekroczenia stanu rachunku z %1 na %2.
					|W okresie %3 - %4, rachunek bankowy ma saldo ujemne, które jest większy niż nowy limit przekroczenia stanu rachunku.';
					|es_ES = 'No se pueden guardar los cambios. Usted está intentando cambiar el límite de sobregiro de %1a %2. 
					| En el periodo %3- %4, la cuenta bancaria tiene un saldo negativo superior al nuevo límite de sobregiro.';
					|es_CO = 'No se pueden guardar los cambios. Usted está intentando cambiar el límite de sobregiro de %1a %2. 
					| En el periodo %3- %4, la cuenta bancaria tiene un saldo negativo superior al nuevo límite de sobregiro.';
					|tr = 'Değişiklikler kaydedilemiyor. %1 olan fazla para çekme limitini %2 olarak değiştirmeye çalışıyorsunuz.
					|%3 - %4 döneminde, banka hesabının eksi bakiyesi yeni fazla para çekme limitinden daha yüksek.';
					|it = 'Impossibile salvare le modifiche. Stai provando a modificare il limite di scoperto da %1 a %2.
					|Nel periodo %3 - %4, il conto corrente ha saldo negativo maggiore del nuovo limite di scoperto.';
					|de = 'Fehler beim Speichern von Änderungen. Sie versuchen die Überziehungsgrenze vom %1 auf %2.
					|Im Zeitraum %3 - %4, hat das Bankkonto einen negativen Saldo, der die neue Überziehungsgrenze überschreitet.'"),
				InitialValues.Limit,
				Record.Limit,
				Format(Record.StartDate, "DLF=D"),
				Format(Record.EndDate, "DLF=D"));
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

#EndRegion