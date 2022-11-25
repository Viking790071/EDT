#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// begin Drive.FullVersion
	Catalogs.CostObjects.UpdateLinkedCostObjectsData(Ref);
	// end Drive.FullVersion
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If GetFunctionalOption("UseProjectManagement") Then
		
		If ValueIsFilled(StartDate) And ValueIsFilled(EndDate) And StartDate > EndDate Then
			CommonClientServer.MessageToUser(NStr("en = 'End date cannot be earlier than Start date.'; ru = 'Дата завершения не может быть раньше даты начала.';pl = 'Data zakończenia nie może by wcześniejsza niż Data rozpoczęcia.';es_ES = 'La Fecha final no puede ser anterior a la Fecha de inicio.';es_CO = 'La Fecha final no puede ser anterior a la Fecha de inicio.';tr = 'Bitiş tarihi, Başlangıç tarihinden önce olamaz.';it = 'La data di Fine non può essere precedente alla data di Avvio.';de = 'Der Fälligkeitstermin darf nicht vor dem Startdatum liegen.'"),
				ThisObject,
				"EndDate",
				,
				Cancel);
		EndIf;
		
		If UseWorkSchedule Then
			FoundAttribute = CheckedAttributes.Find("WorkSchedule");
			If FoundAttribute = Undefined Then
				CheckedAttributes.Add("WorkSchedule");
			EndIf;
		Else
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "WorkSchedule");
		EndIf;
		
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "DurationUnit");
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		
		CurrentUser = UsersClientServer.CurrentUser();
		
		Manager = CurrentUser;
		
		SettingMainCompany = DriveReUse.GetValueByDefaultUser(CurrentUser, "MainCompany");
		If ValueIsFilled(SettingMainCompany) Then
			Company = SettingMainCompany;
		Else
			Company = DriveServer.GetPredefinedCompany();
		EndIf;
		
		If GetFunctionalOption("UseProjectManagement") Then
			
			CalculateDeadlinesAutomatically = True;
			
			If ValueIsFilled(Company) And Not ValueIsFilled(WorkSchedule) Then
				WorkSchedule = Common.ObjectAttributeValue(Company, "BusinessCalendar");
			EndIf;
			
			If ValueIsFilled(WorkSchedule) Then
				UseWorkSchedule = True;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf