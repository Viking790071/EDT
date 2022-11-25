&AtServer
Procedure RunReceiptsBackupAtServer(CommandParameter)

	Query = New Query;
	
	Query.Text = 
	"SELECT ALLOWED
	|	ShiftClosure.Ref
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Ref IN (&CommandParameter)
	|	AND ShiftClosure.Posted
	|	AND ShiftClosure.CashCRSessionStatus = &CashCRSessionStatus
	|	AND ShiftClosure.CashCR.CashCRType = &CashCRTypeFiscalRegister";
	
	Query.SetParameter("CommandParameter", CommandParameter);
	Query.SetParameter("CashCRSessionStatus", Enums.ShiftClosureStatus.Closed);
	Query.SetParameter("CashCRTypeFiscalRegister", Enums.CashRegisterTypes.FiscalRegister);

	Selection = Query.Execute().Select();
	While Selection.Next() Do
	
		ReportAboutRetailSalesObject = Selection.Ref.GetObject();
		If ReportAboutRetailSalesObject.CashCRSessionStatus = Enums.ShiftClosureStatus.Closed Then
			
			ErrorDescription = "";
			Documents.ShiftClosure.RunReceiptsBackup(ReportAboutRetailSalesObject, ErrorDescription);
			
			If ValueIsFilled(ErrorDescription) Then
				
				Message = New UserMessage;
				Message.Text = ErrorDescription;
				Message.Message();
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RunReceiptsBackupAtServer(CommandParameter);
	
	Notify("RefreshFormsAfterClosingCashCRSession");
	
	ShowUserNotification(NStr("en = 'Cash receipt archiving is completed'; ru = 'Архивация кассовых чеков выполнена';pl = 'Paragony kasowe zostały zarchiwizowane';es_ES = 'Archivado del recibo de efectivo se ha finalizado';es_CO = 'Archivado del recibo de efectivo se ha finalizado';tr = 'Nakit tahsilat fişi arşivlemesi tamamlandı';it = 'L''Entrata di cassa degli scontrini è completata';de = 'Die Archivierung des Zahlungseingangs ist abgeschlossen'"));
	
EndProcedure
