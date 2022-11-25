
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT AccessRight("Update", Metadata.Catalogs.AccessGroups)
	     
	 OR AccessParameters("Update", Metadata.Catalogs.AccessGroups,
	         "Ref").RestrictionByCondition Then
		
		ReadOnly = True;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If CurrentObject.Ref = Catalogs.AccessGroups.PersonalAccessGroupsParent(True) Then
		ReadOnly = True;
	EndIf;
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	PersonalAccessGroupsDescription = Undefined;
	
	PersonalAccessGroupsParent = Catalogs.AccessGroups.PersonalAccessGroupsParent(
		True, PersonalAccessGroupsDescription);
	
	If Object.Ref <> PersonalAccessGroupsParent
	   AND Object.Description = PersonalAccessGroupsDescription Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Это наименование зарезервировано.'; en = 'This name is reserved.'; pl = 'Ta nazwa jest zastrzeżona.';es_ES = 'Este nombre se ha reservado.';es_CO = 'Este nombre se ha reservado.';tr = 'Bu isim rezerve edildi.';it = 'Questo nome è riservato.';de = 'Dieser Name ist reserviert.'"),
			,
			"Object.Description",
			,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion
