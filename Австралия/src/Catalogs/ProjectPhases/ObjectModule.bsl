#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Ref.IsEmpty() Then
		RefDeletionMark = False;
		CurrentParent = Catalogs.ProjectPhases.EmptyRef();
	Else
		RefAttributes = Common.ObjectAttributesValues(Ref, "DeletionMark, Parent");
		RefDeletionMark = RefAttributes.DeletionMark;
		CurrentParent = RefAttributes.Parent;
	EndIf;
	
	AdditionalProperties.Insert("CurrentParent", CurrentParent);
	AdditionalProperties.Insert("DeletionMark", RefDeletionMark);
	
	If Not IsProduction And ValueIsFilled(ProductionOrder) Then
		ProductionOrder = Undefined;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("CheckPrevious") And AdditionalProperties.CheckPrevious Then
		ProjectManagement.CheckPreviousPhase(Ref);
	EndIf;
	
	CurrentParent = AdditionalProperties.CurrentParent;
	If Parent <> CurrentParent Then
		
		If ValueIsFilled(CurrentParent) Then
			IsSummaryPhase = ProjectManagement.IsSummaryPhase(CurrentParent);
			If IsSummaryPhase <> CurrentParent.SummaryPhase Then
				LockDataForEdit(CurrentParent.Ref);
				ParentObject = CurrentParent.GetObject();
				ParentObject.SummaryPhase = IsSummaryPhase;
				ParentObject.Write();
			EndIf;
		EndIf;
		
		If ValueIsFilled(Parent) Then
			IsSummaryPhase = ProjectManagement.IsSummaryPhase(Parent);
			If IsSummaryPhase <> Parent.SummaryPhase Then
				LockDataForEdit(Parent.Ref);
				ParentObject = Parent.GetObject();
				ParentObject.SummaryPhase = IsSummaryPhase;
				ParentObject.Write();
			EndIf;
		EndIf;
		
	EndIf;
	
	If DeletionMark <> AdditionalProperties.DeletionMark Then
		
		ProjectManagement.FillInProjectPhasesCodeWBS(Owner);
		
		If ValueIsFilled(Parent) Then
			IsSummaryPhase = ProjectManagement.IsSummaryPhase(Parent);
			If IsSummaryPhase <> Parent.SummaryPhase Then
				LockDataForEdit(Parent);
				ParentObject = Parent.GetObject();
				ParentObject.SummaryPhase = IsSummaryPhase;
				ParentObject.Write();
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	SummaryPhase = False;
	CodeWBS = "";
	PhaseNumberInLevel = 0;
	ActualStartDate = Date(1, 1, 1);
	ActualEndDate = Date(1, 1, 1);
	ActualDuration = 0;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsProduction Then
		CheckedAttributes.Add("ProductionOrder");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ProductionOrder");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf