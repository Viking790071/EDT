#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Capacity = 0 Then
		Capacity = 1;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not PlanningOnWorkcentersLevel Then
		
		UsePlanning = Constants.UseProductionPlanning.Get();
		
		If UsePlanning Then
			CheckedAttributes.Add("Capacity");
			CheckedAttributes.Add("Schedule");
		EndIf;
		
	EndIf;
	
	If Ref = Catalogs.CompanyResourceTypes.AllResources Then
		CheckedAttributes.Clear();
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("MarkWorkcentersAvailabilityForDeletion") Then
		
		JobSettings = New Structure;
		JobSettings.Insert("WorkcenterType", Ref);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
		ExecutionParameters.WaitForCompletion = 0;
		ExecutionParameters.BackgroundJobDescription = NStr("en = 'Clearing of workcenters availability'; ru = 'Очистка доступности рабочих центров';pl = 'Wyczyszczenie dostępności gniazd produkcyjnych';es_ES = 'Eliminación de la disponibilidad de los centros de trabajo';es_CO = 'Eliminación de la disponibilidad de los centros de trabajo';tr = 'İş merkezleri müsaitlik durumunun silinmesi';it = 'Cancellare disponibilità centri di lavoro';de = 'Verrechnung von Verfügbarkeit der Arbeitsabschnitte'");
		
		TimeConsumingOperations.ExecuteInBackground(
			"ProductionPlanningServer.MarkWorkcentersAvailabilityForDeletion",
			JobSettings,
			ExecutionParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf