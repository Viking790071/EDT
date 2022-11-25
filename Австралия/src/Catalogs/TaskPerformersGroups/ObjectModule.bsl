///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;	
	EndIf;
	
	If ValueIsFilled(PerformerRole) Then
		
		Description = String(PerformerRole);
		
		If ValueIsFilled(MainAddressingObject) Then
			Description = Description + ", " + String(MainAddressingObject);
		EndIf;
		
		If ValueIsFilled(AdditionalAddressingObject) Then
			Description = Description + ", " + String(AdditionalAddressingObject);
		EndIf;
	Else
		Description = NStr("ru = 'Без ролевой адресации'; en = 'Without role addressing'; pl = 'Bez roli adresującej';es_ES = 'Sin rol de direccionamiento';es_CO = 'Sin rol de direccionamiento';tr = 'Rol adresleme olmadan';it = 'Senza un indirizzamento di ruolo';de = 'Ohne Rollenadressierung'");
	EndIf;
	
	// Checking for duplicates.
	Query = New Query(
		"SELECT TOP 1
		|	TaskPerformersGroups.Ref
		|FROM
		|	Catalog.TaskPerformersGroups AS TaskPerformersGroups
		|WHERE
		|	TaskPerformersGroups.PerformerRole = &PerformerRole
		|	AND TaskPerformersGroups.MainAddressingObject = &MainAddressingObject
		|	AND TaskPerformersGroups.AdditionalAddressingObject = &AdditionalAddressingObject
		|	AND TaskPerformersGroups.Ref <> &Ref");
	Query.SetParameter("PerformerRole", PerformerRole);
	Query.SetParameter("MainAddressingObject", MainAddressingObject);
	Query.SetParameter("AdditionalAddressingObject", AdditionalAddressingObject);
	Query.SetParameter("Ref", Ref);
	
	If NOT Query.Execute().IsEmpty() Then
		Raise(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Уже есть группа исполнителей задач, для которой заданы:
			           |роль исполнителя ""%1"",
			           |основной объект адресации ""%2""
			           |и дополнительный объект адресации ""%3""'; 
			           |en = 'There is already the task assignee group for which
			           |assignee role ""%1"",
			           |main addressing object ""%2"",
			           |and additional addressing object ""%3"" are set'; 
			           |pl = 'Już istnieje grupa wykonawców dla której
			           |rola wykonawcy ""%1"",
			           |główny obiekt adresacji ""%2"",
			           |i dodatkowy obiekt adresacji ""%3"" są ustawione';
			           |es_ES = 'Ya existe el grupo de ejecutores de tareas para el que se han establecido 
			           |el rol de ejecutor ""%1"", 
			           |el objeto de direccionamiento principal ""%2"" 
			           |y el objeto de direccionamiento adicional ""%3"".';
			           |es_CO = 'Ya existe el grupo de ejecutores de tareas para el que se han establecido 
			           |el rol de ejecutor ""%1"", 
			           |el objeto de direccionamiento principal ""%2"" 
			           |y el objeto de direccionamiento adicional ""%3"".';
			           |tr = 'Atananın rolü ""%1"", 
			           | ana gönderim hedefi""%2"", 
			           |ve ek gönderim hedefleri ""%3"" belirlenen göreve atanan grubu zaten mevcut
			           |';
			           |it = 'Esiste già un gruppo di esecutori de compiti per i quali sono indicati:
			           |il ruolo dell''esecutore ""%1"",
			           |l''oggetto d''indirizzamento principale ""%2""
			           |e l''oggetto di indirizzamento aggiuntivo ""%3""';
			           |de = 'Es gibt bereits eine Gruppe der Bevollmächtiger für die
			           |die Rolle von Bevollmächtiger""%1"",
			           |Hauptobjekt von Adressierung""%2"",
			           |und zusätzliches Adressierungsobjekt""%3"" eingegeben sind'"),
			String(PerformerRole),
			String(MainAddressingObject),
			String(AdditionalAddressingObject)));
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf