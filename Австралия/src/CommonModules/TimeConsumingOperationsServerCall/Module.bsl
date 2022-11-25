#Region Private

Function ActionsCompleted(Val JobsToCheck, JobsToCancel) Export
	
	Result = TimeConsumingOperations.ActionsCompleted(JobsToCheck);
	For each JobID In JobsToCancel Do
		TimeConsumingOperations.CancelJobExecution(JobID);
		Result.Insert(JobID, New Structure("Status", "Canceled"));
	EndDo;
	Return Result;
	
EndFunction

#EndRegion
