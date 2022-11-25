#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ThisObject.Count() = 0 And ThisObject.Modified() Then
		
		FilterParameters = ThisObject.Filter;
		
		Parameters = New Structure;
		Parameters.Insert("Company", FilterParameters.Company.Value);
		Parameters.Insert("BankAccount", FilterParameters.BankAccount.Value);
		Parameters.Insert("StartDate", FilterParameters.StartDate.Value);
		Parameters.Insert("EndDate", FilterParameters.EndDate.Value);
		
		If Not Common.ObjectAttributeValue(Parameters.BankAccount, "AllowNegativeBalance")
			And InformationRegisters.OverdraftLimits.IsOverdraftUsedInPayments(Parameters) Then
			
			MessageText = NStr("en = 'Cannot delete the line where the Bank account is ""%1"", Start date is %2, and End date is %3.
						|These settings are already applied for recording payments.'; 
						|ru = 'Не удалось удалить строку, где указан банковский счет ""%1"", дата начала ""%2"" и дата окончания ""%3"".
						|Эти настройки уже применяются для записи платежей.';
						|pl = 'Nie można usunąć wiersza, gdzie Rachunek bankowy to ""%1"", Data rozpoczęcia to %2, i Data zakończenia to %3.
						|Te ustawienia są już zastosowane do rejestrowania płatności.';
						|es_ES = 'No se puede eliminar la línea en la que la cuenta bancaria es ""%1"", la fecha de inicio es%2 , y la fecha final es%3.
						|Estos ajustes ya se aplican para registrar los pagos.';
						|es_CO = 'No se puede eliminar la línea en la que la cuenta bancaria es ""%1"", la fecha de inicio es%2 , y la fecha final es%3.
						|Estos ajustes ya se aplican para registrar los pagos.';
						|tr = 'Banka hesabı ""%1"", Başlangıç tarihi %2 ve Bitiş tarihi %3 olan satır silinemiyor.
						|Bu ayarlar ödemelerin kaydedilmesi için zaten uygulanmış durumda.';
						|it = 'Impossibile eliminare la riga dove il Conto corrente è ""%1"", Data di avvio è %2 e Data di fine è %3.
						|Queste impostazioni sono già state applicazione per registrare i pagamenti.';
						|de = 'Fehler beim Löschen der Zeile mit dem Bankkonto ""%1"", Startdatum %2, und Enddatum %3.
						|Diese Einstellungen sind für Buchung von Zahlungen bereits verwendet.'");
			Cancel = True;
			Raise StringFunctionsClientServer.SubstituteParametersToString(MessageText,
				Parameters.BankAccount, Format(Parameters.StartDate, "DLF=D"), Format(Parameters.EndDate, "DLF=D"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf