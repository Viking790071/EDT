#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InitialSetupDone = Constants.KitProcessingUpdateWasCompleted.Get();
	If Parameters.Property("FromInfobaseUpdate")Then
		
		NoNeedForProcessing = InitialSetupDone;
		
		If Not InitialSetupDone Then
			
			If Constants.UseKitProcessing.Get() Then
				
				Query = New Query;
				Query.Text = 
				"SELECT TOP 1
				|	Production.Ref AS Ref
				|FROM
				|	Document.Production AS Production
				|WHERE
				|	Production.Posted
				|
				|UNION ALL
				|
				|SELECT TOP 1
				|	ProductionOrder.Ref
				|FROM
				|	Document.ProductionOrder AS ProductionOrder
				|WHERE
				|	ProductionOrder.Posted";
				
				QueryResult = Query.Execute();
				
				If QueryResult.IsEmpty() Then
					
					Constants.KitProcessingUpdateWasCompleted.Set(True);
					NoNeedForProcessing = True;
				
				EndIf;
				
			Else
				
				Constants.KitProcessingUpdateWasCompleted.Set(True);
				NoNeedForProcessing = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If InitialSetupDone Then
		
		Items.GroupFirst.Visible = False;
		Items.GroupSecond.Visible = True;
		Items.GroupThird.Visible = False;
		
		CurrentItem = Items.StartUpdate;
		
	Else
		
		Items.GroupFirst.Visible = True;
		Items.GroupSecond.Visible = False;
		Items.GroupThird.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NoNeedForProcessing Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not InitialSetupDone Then
		
		StandardProcessing	= False;
		Cancel				= True;
		
		WarningText = NStr("en = 'It is required to install Kit processing updates.'; ru = 'Требуется для установки обновления обработки комплектации.';pl = 'Wymagana jest instalacja aktualizacji Przetworzenia zestawu.';es_ES = 'Se requiere para instalar las actualizaciones de procesamiento del kit.';es_CO = 'Se requiere para instalar las actualizaciones de procesamiento del kit.';tr = 'Set işleme güncellemelerinin yüklenmesi gerekiyor.';it = 'È richiesta l''installazione degli aggiornamenti dell''elaborazione del Kit.';de = 'Ist für Installation von Updates für Kit-Bearbeitung erforderlich.'");
		
		If Exit Then
			Return;
		EndIf;
			
		Buttons = New ValueList;
		Buttons.Add("Exit", NStr("en = 'Exit'; ru = 'Завершить работу';pl = 'Zakończ';es_ES = 'Salir';es_CO = 'Salir';tr = 'Çıkış';it = 'Uscire';de = 'Verlassen'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annullare';de = 'Abbrechen'"));
		
		Notification = New NotifyDescription("ConfirmFormClosingEnd", ThisObject, Parameters);
		ShowQueryBox(Notification, WarningText, Buttons,, "Cancel");
		
	Else
		
		Notify("KitProcessingInfobaseUpdateClosing");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure StartUpdate(Command)
	
	TimeConsumingOperation = StartUpdateTimeConsumingOperation();
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("TimeConsumingOperation", TimeConsumingOperation);
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
	IdleParameters.MessageText = NStr("en = 'Kit processing update installer'; ru = 'Программа установки обновления обработки комплектации';pl = 'Instalator aktualizacji przetwarzania zestawu';es_ES = 'Instalador de actualización de procesamiento del kit';es_CO = 'Instalador de actualización de procesamiento del kit';tr = 'Set işleme güncellemesi yükleyici';it = 'Programma di installazione aggiornamenti dell''elaborazione Kit';de = 'Installateur von Updates für Kit-Bearbeitung'");
	
	CompletionNotification = New NotifyDescription("StartUpdateCompletion", ThisObject, ExecuteParameters);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure StartUpdateCompletion(Result, ExecuteParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		Return;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The update is completed with errors.'; ru = 'Обновление завершилось ошибкой.';pl = 'Aktualizacja została zakończona z błędami.';es_ES = 'La actualización se ha finalizado con errores.';es_CO = 'La actualización se ha finalizado con errores.';tr = 'Güncelleme hatalarla tamamlandı.';it = 'Aggiornamento completato con errori.';de = 'Die Aktualisierung ist mit Fehler abgeschlossen.'"));
		CommonClientServer.MessageToUser(Result.BriefErrorPresentation);
		
	ElsIf Result.Status = "Completed" Then
		
		SetKitProcessingUpdateWasCompleted();
		InitialSetupDone = True;
		
		Items.GroupFirst.Visible = False;
		Items.GroupSecond.Visible = True;
		Items.GroupThird.Visible = False;
		
		NeedForDeletion = GetFromTempStorage(Result.ResultAddress);
		
		If NeedForDeletion = True Then
			
			Items.DecorationMarkForDeletion.Visible = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetKitProcessingUpdateWasCompleted(Value = True)
	
	Constants.KitProcessingUpdateWasCompleted.Set(Value);
	
EndProcedure

&AtServer
Function StartUpdateTimeConsumingOperation() Export
	
	ProcedureParameters = New Structure;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Kit processing update installer'; ru = 'Программа установки обновления обработки комплектации';pl = 'Instalator aktualizacji przetwarzania zestawu';es_ES = 'Instalador de actualizaciones de procesamiento del kit';es_CO = 'Instalador de actualizaciones de procesamiento del kit';tr = 'Set işleme güncellemesi yükleyici';it = 'Programma di installazione aggiornamenti dell''elaborazione Kit';de = 'Installateur von Updates für Kit-Bearbeitung'");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.KitProcessingInfobaseUpdate.StartUpdate",
		ProcedureParameters,
		ExecutionParameters);
	
	Return TimeConsumingOperation;
	
EndFunction

&AtClient
Procedure ConfirmFormClosingEnd(Response, Parameters) Export
	
	If Response = "Exit" Then
		Terminate();
	EndIf;
	
EndProcedure

#EndRegion