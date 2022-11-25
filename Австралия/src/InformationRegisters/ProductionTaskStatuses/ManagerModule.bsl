#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function SetProductionTaskStatus(ProductionTask, Status, SuspendReason = Undefined, Comment = Undefined) Export
	
	Result = False;
	
	CurrentStatus = Enums.ProductionTaskStatuses.EmptyRef();
	CurrentDate = CurrentSessionDate();
	LastDate = CurrentDate;
	ActiveDuration = 0;
	
	If Common.ObjectAttributeValue(ProductionTask, "Posted") Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	ProductionTaskStatusesSliceLast.Status AS Status,
			|	ProductionTaskStatusesSliceLast.Period AS Period
			|FROM
			|	InformationRegister.ProductionTaskStatuses.SliceLast(&CurrentDate, ProductionTask = &ProductionTask) AS ProductionTaskStatusesSliceLast";
		
		Query.SetParameter("CurrentDate", CurrentDate);
		Query.SetParameter("ProductionTask", ProductionTask);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			CurrentStatus = SelectionDetailRecords.Status;
			LastDate = SelectionDetailRecords.Period;
		EndIf;
		
		If CurrentStatus <> Status
			And CurrentStatus <> Enums.ProductionTaskStatuses.Completed
			And CurrentStatus <> Enums.ProductionTaskStatuses.Canceled
			And CurrentStatus <> Enums.ProductionTaskStatuses.Split Then
			
			Result = True;
			
			If Status = Enums.ProductionTaskStatuses.InProgress Then
				
				ProductionTaskObject = ProductionTask.GetObject();
				
				// Change document start date
				If Not ValueIsFilled(CurrentStatus) Or CurrentStatus = Enums.ProductionTaskStatuses.Open Then
					If Not ValueIsFilled(ProductionTaskObject.StartDate) Then
						ProductionTaskObject.StartDate = CurrentDate;
					EndIf;
				EndIf;
				
				ProductionTaskObject.Status = Status;
				ProductionTaskObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
				ProductionTaskObject.Write(DocumentWriteMode.Posting);
				
			ElsIf Status = Enums.ProductionTaskStatuses.Completed Then
				
				// Change document end date
				ProductionTaskObject = ProductionTask.GetObject();
				If Not ValueIsFilled(ProductionTaskObject.EndDate) Then
					ProductionTaskObject.EndDate = CurrentDate;
				EndIf;
				If CurrentStatus = Enums.ProductionTaskStatuses.Open Then
					If Not ValueIsFilled(ProductionTaskObject.StartDate) Then
						ProductionTaskObject.StartDate = CurrentDate;
					EndIf;
				EndIf;
				ProductionTaskObject.Status = Status;
				ProductionTaskObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
				ProductionTaskObject.Write(DocumentWriteMode.Posting);
				
				If CurrentStatus = Enums.ProductionTaskStatuses.InProgress Then
					ActiveDuration = (CurrentDate - LastDate)/60;
				EndIf;
				
			ElsIf Status = Enums.ProductionTaskStatuses.Suspended Then
				
				If CurrentStatus = Enums.ProductionTaskStatuses.InProgress Then
					
					ActiveDuration = (CurrentDate - LastDate)/60;
					
					// Change document end date
					ProductionTaskObject = ProductionTask.GetObject();
					ProductionTaskObject.Status = Status;
					ProductionTaskObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
					ProductionTaskObject.Write(DocumentWriteMode.Posting);
					
				Else
					Result = False;
				EndIf;
				
			ElsIf Status = Enums.ProductionTaskStatuses.Canceled Then
				
				// Change document end date
				ProductionTaskObject = ProductionTask.GetObject();
				If Not ValueIsFilled(ProductionTaskObject.EndDate) Then
					ProductionTaskObject.EndDate = CurrentDate;
				EndIf;
				If CurrentStatus = Enums.ProductionTaskStatuses.Open Then
					If Not ValueIsFilled(ProductionTaskObject.StartDate) Then
						ProductionTaskObject.StartDate = CurrentDate;
					EndIf;
				EndIf;
				ProductionTaskObject.Status = Status;
				ProductionTaskObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
				ProductionTaskObject.Write(DocumentWriteMode.Posting);
				
			ElsIf Status = Enums.ProductionTaskStatuses.Split Then
				
				// Change document end date
				ProductionTaskObject = ProductionTask.GetObject();
				If Not ValueIsFilled(ProductionTaskObject.EndDate) Then
					ProductionTaskObject.EndDate = CurrentDate;
				EndIf;
				If CurrentStatus = Enums.ProductionTaskStatuses.Open Then
					If Not ValueIsFilled(ProductionTaskObject.StartDate) Then
						ProductionTaskObject.StartDate = CurrentDate;
					EndIf;
				EndIf;
				ProductionTaskObject.Status = Status;
				ProductionTaskObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
				ProductionTaskObject.Write(DocumentWriteMode.Posting);
				
			EndIf;
			
			If Result Then
				
				RegisterRecord = InformationRegisters.ProductionTaskStatuses.CreateRecordManager();
				RegisterRecord.Period = CurrentDate;
				RegisterRecord.ProductionTask = ProductionTask;
				RegisterRecord.Status = Status;
				RegisterRecord.ActiveDuration = ActiveDuration;
				RegisterRecord.SuspendReason = SuspendReason;
				RegisterRecord.Comment = Comment;
				
				RegisterRecord.Write();
				
			EndIf;
			
		EndIf;
		
	ElsIf Status <> Enums.ProductionTaskStatuses.Open Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot change this status for %1. First, post this document.'; ru = 'Не удается изменить статус для %1. Сначала проведите этот документ.';pl = 'Nie można zmienić tego statusu dla %1. Najpierw zatwierdź dokument.';es_ES = 'No se puede cambiar este estado para %1. Primero, envíe este documento.';es_CO = 'No se puede cambiar este estado para %1. Primero, envíe este documento.';tr = 'Bu durum %1 olarak değiştirilemiyor. Önce bu belgeyi kaydedin.';it = 'Impossibile modificare questo stato per %1. Innanzitutto pubblicare questo documento.';de = 'Dieser Status für %1 kann nicht geändert werden. Zuerst dieses Dokument buchen.'"), ProductionTask);
		CommonClientServer.MessageToUser(ErrorMessage, ProductionTask);
		
	EndIf;
	
	If Not Result And Status <> Enums.ProductionTaskStatuses.Open Then
		
		ErrorMessage = ErrorMessageWrongStatus(ProductionTask, Status);
		CommonClientServer.MessageToUser(ErrorMessage, ProductionTask);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function ErrorMessageWrongStatus(ProductionTask, Status)
	
	ErrorMessage = "";
	
	If Status = Enums.ProductionTaskStatuses.InProgress Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set status ""In progress"" for Production task %1. You can change status to ""In progress"" only for a Production task with status ""Open"" or ""Suspended"".'; ru = 'Невозможно установить статус ""В работе"" для производственной задачи %1. Статус может быть изменен на ""В работе"" только для производственной задачи со статусом ""Открыта"" или ""Приостановлена"".';pl = 'Nie można ustawić statusu ""W toku"" dla zadania produkcyjnego %1. Możesz zmienić status na ""W toku"" tylko dla Zadania produkcyjnego o statusie ""Otwarte"" lub ""Zawieszone"".';es_ES = 'No se puede establecer el estado ""En progreso"" para la tarea de producción %1. Se puede cambiar el estado a ""En progreso"" sólo para una tarea de producción en estado ""Abrir"" o ""Suspendido"".';es_CO = 'No se puede establecer el estado ""En progreso"" para la tarea de producción %1. Se puede cambiar el estado a ""En progreso"" sólo para una tarea de producción en estado ""Abrir"" o ""Suspendido"".';tr = 'Üretim görevi %1 için ""İşlemde"" durumu belirtilemiyor. Sadece ""Açık"" veya ""Askıya alındı"" durumundaki üretim görevlerinin durumu ""İşlemde"" olarak değiştirilebilir.';it = 'Impossibile impostare lo stato ""In lavorazione"" per l''Incarico di produzione %1. È possibile modificare lo stato in ""In lavorazione"" solamente per un Incarico di produzione con stato ""Aperto"" o ""Sospeso"".';de = 'Der Status ""In Bearbeitung"" für die Produktionsaufgabe %1 kann nicht gesetzt werden. Der Status kann nur bei einer Produktionsaufgabe mit dem Status ""Offen"" oder ""Suspendiert"" geändert werden.'"),
			ProductionTask);
		
	ElsIf Status = Enums.ProductionTaskStatuses.Suspended Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set status ""Suspended"" for Production task %1. You can change status to ""Suspended"" only for a Production task with status ""In progress"".'; ru = 'Невозможно установить статус ""Приостановлена"" для производственной задачи %1. Статус может быть изменен на ""Приостановлена"" только для производственной задачи со статусом ""В работе"".';pl = 'Nie można zmienić statusu ""Zawieszone"" dla Zadania produkcyjnego %1. Status można zmienić na ""Zawieszone"" tylko dla Zadania produkcyjnego o statusie ""W toku"".';es_ES = 'No se puede establecer el estado ""Suspendido"" para la tarea de producción %1. Se puede cambiar el estado a ""Suspendido"" sólo para una tarea de producción con estado ""En progreso"".';es_CO = 'No se puede establecer el estado ""Suspendido"" para la tarea de producción %1. Se puede cambiar el estado a ""Suspendido"" sólo para una tarea de producción con estado ""En progreso"".';tr = 'Üretim görevi %1 için ""Askıya alındı"" durumu belirtilemiyor. Sadece ""İşlemde"" durumundaki üretim görevlerinin durumu ""Askıya alındı"" olarak değiştirilebilir.';it = 'Impossibile impostare lo stato ""Sospeso"" per l''Incarico di produzione %1. È possibile modificare lo stato in ""Sospeso"" solo per un Incarico di produzione con stato ""In lavorazione"".';de = 'Der Status ""Suspendiert"" für die Produktionsaufgabe %1 kann nicht gesetzt werden. Der Status kann nur bei einer Produktionsaufgabe mit dem Status ""In Bearbeitung"" zu ""Suspendiert"" geändert werden.'"),
			ProductionTask);
		
	ElsIf Status = Enums.ProductionTaskStatuses.Completed Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set status ""Completed"" for Production task %1. You can change status to ""Completed"" only for a Production task with status ""Open"", ""In progress"",  or ""Suspended"".'; ru = 'Невозможно установить статус ""Завершена"" для производственной задачи %1. Статус может быть изменен на ""Завершена"" только для производственной задачи со статусом ""Открыта"", ""В работе"" или ""Приостановлена"".';pl = 'Nie można ustawić statusu ""Zakończone"" dla Zadania produkcyjnego %1. Status można zmienić na ""Zakończone"" tylko dla Zadania produkcyjnego o statusie ""Otwarte"", ""W toku"", lub ""Zawieszone"".';es_ES = 'No se puede establecer el estado ""Finalizado"" para la tarea de producción %1. El estado se puede cambiar a ""Finalizado"" sólo para una tarea de producción con estado ""Abrir"", ""En progreso"", o ""Suspendido"".';es_CO = 'No se puede establecer el estado ""Finalizado"" para la tarea de producción %1. El estado se puede cambiar a ""Finalizado"" sólo para una tarea de producción con estado ""Abrir"", ""En progreso"", o ""Suspendido"".';tr = 'Üretim görevi %1 için ""Tamamlandı"" durumu belirtilemiyor. Sadece ""Açık"", ""İşlemde"" veya ""Askıya alındı"" durumundaki üretim görevlerinin durumu ""Tamamlandı"" olarak değiştirilebilir.';it = 'Impossibile impostare lo stato ""Completato"" per l''Incarico di produzione %1. È possibile modificare lo stato in ""Completato"" solamente per un Incarico di produzione con stato ""Aperto"", ""In lavorazione"" o ""Sospeso"".';de = 'Der Status ""Abgeschlossen"" für die Produktionsaufgabe %1 kann nicht gesetzt werden. Der Status kann nur bei einer Produktionsaufgabe mit dem Status ""Offen"", ""In Bearbeitung"", oder ""Suspendiert"" zu ""Abgeschlossen"" geändert werden.'"),
			ProductionTask);
		
	ElsIf Status = Enums.ProductionTaskStatuses.Canceled Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set status ""Canceled"" for Production task %1. You can change status to ""Canceled"" only for a Production task with status ""Open"", ""In progress"", or ""Suspended"".'; ru = 'Невозможно установить статус ""Отменена"" для производственной задачи %1. Статус может быть изменен на ""Отменена"" только для производственной задачи со статусом ""Открыта"", ""В работе"" или ""Приостановлена"".';pl = 'Nie można ustawić statusu ""Anulowane"" dla Zadania produkcyjnego %1. Status można zmienić na ""Anulowane"" tylko dla Zadania produkcyjnego o statusie ""Otwarte"", ""W toku"", lub ""Zawieszone"".';es_ES = 'No se puede establecer el estado ""Cancelado"" para la tarea de producción %1. El estado se puede cambiar a ""Cancelado"" sólo para una tarea de producción con estado ""Abrir"", ""En progreso"", o ""Suspendido"".';es_CO = 'No se puede establecer el estado ""Cancelado"" para la tarea de producción %1. El estado se puede cambiar a ""Cancelado"" sólo para una tarea de producción con estado ""Abrir"", ""En progreso"", o ""Suspendido"".';tr = 'Üretim görevi %1 için ""İptal edildi"" durumu belirtilemiyor. Sadece ""Açık"", ""İşlemde"" veya ""Askıya alındı"" durumundaki üretim görevlerinin durumu ""İptal edildi"" olarak değiştirilebilir.';it = 'Impossibile impostare lo stato ""Annullato"" per l''Incarico di produzione %1. È possibile modificare lo stato in ""Annullato"" solamente per un Incarico di produzione con stato ""Aperto"", ""In lavorazione"" o ""Sospeso"".';de = 'Der Status ""Abgebrochen"" für die Produktionsaufgabe %1 kann nicht gesetzt werden. Der Status kann nur bei einer Produktionsaufgabe mit dem Status ""Offen"", ""In Bearbeitung"", oder ""Suspendiert"" geändert werden.'"),
			ProductionTask);
		
	EndIf;
	
	Return ErrorMessage;
	
EndFunction

#EndRegion

#EndIf