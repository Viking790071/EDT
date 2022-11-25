#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not CheckDescriptionIsUnique(Description) Then
		
		ErrorTemplate = NStr("en = 'The value ""%1"" of the field ""Description"" is not unique!'; ru = 'Значение ""%1"" поля ""Наименование"" уже существует.';pl = 'Wartość ""%1"" pola ""Opis"" nie jest unikalna!';es_ES = 'El valor ""%1"" del campo ""Descripción"" no es único.';es_CO = 'El valor ""%1"" del campo ""Descripción"" no es único.';tr = '""Tanım"" alanının ""%1"" değeri benzersiz değil!';it = 'Il valore ""%1"" del campo ""Descrizione"" non è univoco!';de = 'Der Wert ""%1"" des Felds ""Beschreibung"" ist nicht einzigartig!'");
		ErrorMessage  = StrTemplate(ErrorTemplate, Description);
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Description", Cancel);
		
	EndIf;
	
EndProcedure

Procedure OnReadPresentationsAtServer(Object) Export
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#Region Private

Function CheckDescriptionIsUnique(CurrentObjectDescription)
	
	Query = New Query;
	Query.Text = 
	"SELECT 
	|	COUNT(DISTINCT TypesOfAccounting.Ref) AS RefCount
	|FROM
	|	Catalog.TypesOfAccounting AS TypesOfAccounting
	|WHERE
	|	TypesOfAccounting.Description = &Description";
	
	Query.SetParameter("Description", CurrentObjectDescription);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() And SelectionDetailRecords.RefCount > 1 Then
		Return False;
	EndIf;

	Return True;
	
EndFunction
	
#EndRegion

#EndIf