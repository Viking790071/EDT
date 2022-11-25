#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure SetProjectPhaseOrder(ProjectPhase, OrderNumber) Export 
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ProjectPhasesOrder.CreateRecordManager();
	RecordManager.ProjectPhase = ProjectPhase;
	RecordManager.Read();
	
	RecordManager.ProjectPhase = ProjectPhase;
	RecordManager.Order = OrderNumber;
	RecordManager.Write(True);
	
EndProcedure

#EndRegion

#EndIf