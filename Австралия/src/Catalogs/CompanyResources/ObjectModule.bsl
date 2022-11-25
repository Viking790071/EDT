#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If Not ValueIsFilled(ResourceValue) Then
		ResourceValue = Undefined;	
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
	If ValueIsFilled(WorkcenterType) Then
		Schedule = Common.ObjectAttributeValue(WorkcenterType, "Schedule");
	EndIf;
	
	If Capacity = 0 Then
		Capacity = 1;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PlanningOnWorkcentersLevel = Common.ObjectAttributeValue(WorkcenterType, "PlanningOnWorkcentersLevel");
	
	If PlanningOnWorkcentersLevel = True Then
		
		UsePlanning = Constants.UseProductionPlanning.Get();
		
		If UsePlanning Then
			CheckedAttributes.Add("Capacity");
			CheckedAttributes.Add("Schedule");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

