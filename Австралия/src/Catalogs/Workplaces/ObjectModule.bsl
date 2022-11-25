#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)

	CurrentUser = InfobaseUsers.CurrentUser();
	Description = ?(IsBlankString(String(Code)), NStr("en = 'Workplace'; ru = 'Рабочее место';pl = 'Miejsce pracy';es_ES = 'Lugar de trabajo';es_CO = 'Lugar de trabajo';tr = 'Çalışma alanı';it = 'Postazione di lavoro';de = 'Arbeitsplatz'"), String(Code))
	             + ?(IsBlankString(String(Code)), ": ", "/")
	             + ?(IsBlankString(String(CurrentUser)), NStr("en = 'User'; ru = 'Пользователь';pl = 'Użytkownik';es_ES = 'Usuario';es_CO = 'Usuario';tr = 'Kullanıcı';it = 'Utente';de = 'Benutzer'"), String(CurrentUser));
		 
	// Add item existence check with such description.
	Query = New Query("
	|SELECT
	|    COUNT(*) AS Quantity
	|FROM
	|    Catalog.Workplaces AS Workplaces
	|WHERE
	|    Workplaces.Description LIKE &Description
	|    AND Workplaces.Ref <> &Ref
	|");

	Query.SetParameter("Description", "%" + Description + "%");
	Query.SetParameter("Ref"      , Ref);

	Quantity = Query.Execute().Unload()[0].Quantity;
	If Quantity > 0 Then
		Description = Description + " (" + String(Quantity + 1) + ")";
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If DeletionMark Then
		If EquipmentManagerServerCall.GetClientWorkplace() = Ref Then
			EquipmentManagerServerCall.SetClientWorkplace(Catalogs.Workplaces.EmptyRef());
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

EndProcedure

#EndRegion

#EndIf