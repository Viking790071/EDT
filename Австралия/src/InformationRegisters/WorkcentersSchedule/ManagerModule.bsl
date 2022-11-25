#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ClearWIPSchedule(WorkInProgress) Export
	
	RecordsSet = InformationRegisters.WorkcentersSchedule.CreateRecordSet();
	RecordsSet.Filter.Operation.Set(WorkInProgress);
	RecordsSet.Write(True);
	
EndProcedure

#EndRegion

#EndIf