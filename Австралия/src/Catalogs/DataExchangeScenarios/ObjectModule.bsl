#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		UseScheduledJob = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Deleting a scheduled job if necessary.
	If DeletionMark Then
		
		DeleteScheduledJob(Cancel);
		
	EndIf;
	
	// Updating the platform cache for reading relevant settings of data exchange scenario by the 
	// DataExchangeCached.DataExchangeSettings procedure.
	RefreshReusableValues();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	GUIDScheduledJob = "";
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteScheduledJob(Cancel);
	
EndProcedure

#EndRegion

#Region Private

// Deletes a scheduled job.
//
// Parameters:
//  Cancel                     - Boolean - a cancellation flag. It is set to True if errors occur 
//                                       upon the procedure execution.
//  ScheduledJobObject - a scheduled job object to be deleted.
// 
Procedure DeleteScheduledJob(Cancel)
	
	SetPrivilegedMode(True);
	
	// Defining a scheduled job.
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(GUIDScheduledJob);
	
	If ScheduledJobObject <> Undefined Then
		
		Try
			ScheduledJobObject.Delete();
		Except
			MessageString = NStr("ru = 'Ошибка при удалении регламентного задания: %1'; en = 'Error deleting the scheduled job: %1'; pl = 'Błąd podczas usunięcia zaplanowanego zadania: %1';es_ES = 'Ha ocurrido un error al eliminar la tarea programada: %1';es_CO = 'Ha ocurrido un error al eliminar la tarea programada: %1';tr = 'Planlanmış işi kaldırırken bir hata oluştu: %1';it = 'Errore durante l''eliminazione del processo pianificato: %1';de = 'Beim Entfernen des geplanten Jobs ist ein Fehler aufgetreten: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, BriefErrorDescription(ErrorInfo()));
			DataExchangeServer.ReportError(MessageString, Cancel);
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
