
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Title = Parameters.Title;
	
	PresentationsArray = ?(Parameters.IsFilter,
		StringFunctionsClientServer.SplitStringIntoSubstringsArray(Parameters.Purpose, ", "),
		Undefined);
	
	If Parameters.SelectUsers Then
		AddTypeRow(Catalogs.Users.EmptyRef(), Type("CatalogRef.Users"), PresentationsArray);
	EndIf;
	
	If ExternalUsers.UseExternalUsers() Then
		
		BlankRefs = UsersInternalCached.BlankRefsOfAuthorizationObjectTypes();
		For Each BlankRef In BlankRefs Do
			AddTypeRow(BlankRef, TypeOf(BlankRef), PresentationsArray);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	Close(Purpose);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddTypeRow(Value, Type, PresentationsArray)
	
	Presentation = Metadata.FindByType(Type).Synonym;
	
	If Parameters.IsFilter Then
		Mark = PresentationsArray.Find(Presentation) <> Undefined;
	Else
		FilterParameters = New Structure;
		FilterParameters.Insert("UsersType", Value);
		FoundRows = Parameters.Purpose.FindRows(FilterParameters);
		Mark = FoundRows.Count() = 1;
	EndIf;
	
	Purpose.Add(Value, Presentation, Mark);
	
EndProcedure

#EndRegion