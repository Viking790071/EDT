#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DescriptonTemplate = NStr("en = '%1 and %2'; ru = '%1 и %2';pl = '%1 oraz %2';es_ES = '%1 y %2';es_CO = '%1 y %2';tr = '%1 ve %2';it = '%1 e %2';de = '%1 und %2'");
	Description = StringFunctionsClientServer.SubstituteParametersToString(
		DescriptonTemplate,
		TypeOfNewObject,
		TypeOfExistingObject);
		
	CheckExistingRules(Cancel);
		
EndProcedure

#EndRegion

#Region Private

Procedure CheckExistingRules(Cancel)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	DuplicateRules.Ref AS Ref
		|FROM
		|	Catalog.DuplicateRules AS DuplicateRules
		|WHERE
		|	DuplicateRules.TypeOfNewObject = &TypeOfNewObject
		|	AND DuplicateRules.TypeOfExistingObject = &TypeOfExistingObject
		|	AND NOT DuplicateRules.DeletionMark
		|	AND DuplicateRules.Ref <> &Ref";
	
	Query.SetParameter("TypeOfExistingObject",	TypeOfExistingObject);
	Query.SetParameter("TypeOfNewObject",		TypeOfNewObject);
	Query.SetParameter("Ref",					Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		MessageText = NStr("en = 'Rule for such objects already exists'; ru = 'Для этих объектов уже существует правило';pl = 'Reguła dla takich obiektów już istnieje';es_ES = 'La regla para tales objetos ya existe';es_CO = 'La regla para tales objetos ya existe';tr = 'Bu tür nesneler için zaten bir kural var';it = 'La regola per questi oggetti già esiste';de = 'Regel für solche Objekte existiert bereits'");
		DriveServer.ShowMessageAboutError(Undefined, MessageText, , , , Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf