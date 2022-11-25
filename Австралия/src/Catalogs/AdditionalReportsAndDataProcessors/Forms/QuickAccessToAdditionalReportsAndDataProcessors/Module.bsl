#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Быстрый доступ к команде ""%1""'; en = 'Quick access to ""%1"" command'; pl = 'Szybki dostęp do polecenia ""%1""';es_ES = 'Comando de acceso rápido a ""%1""';es_CO = 'Comando de acceso rápido a ""%1""';tr = '""%1"" komutuna hızlı erişim';it = 'Accesso rapido al comando ""%1""';de = 'Schnellzugriff auf den Befehl ""%1""'"), Parameters.CommandPresentation);
	
	FillTables();
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region AllUsersFormTableItemEventHandlers

&AtClient
Procedure AllUsersDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(AllUsers, ShortListUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure AllUsersDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region ShortListUsersFormTableItemEventHandlers

&AtClient
Procedure ShortListUsersDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(ShortListUsers, AllUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure ShortListUsersDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RevokeCommandAccessFromAllUsers(Command)
	
	DraggedItemsArray = New Array;
	
	For Each RowDetails In ShortListUsers Do
		DraggedItemsArray.Add(RowDetails);
	EndDo;
	
	MoveUsers(AllUsers, ShortListUsers, DraggedItemsArray);
	
EndProcedure

&AtClient
Procedure RevokeCommandAccessFromSelectedUsers(Command)
	
	DraggedItemsArray = New Array;
	
	For Each SelectedRow In Items.ShortListUsers.SelectedRows Do
		DraggedItemsArray.Add(Items.ShortListUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(AllUsers, ShortListUsers, DraggedItemsArray);
	
EndProcedure

&AtClient
Procedure GrantAccessToAllUsers(Command)
	
	DraggedItemsArray = New Array;
	
	For Each RowDetails In AllUsers Do
		DraggedItemsArray.Add(RowDetails);
	EndDo;
	
	MoveUsers(ShortListUsers, AllUsers, DraggedItemsArray);
	
EndProcedure

&AtClient
Procedure GrantCommandAccessToSelectedUsers(Command)
	
	DraggedItemsArray = New Array;
	
	For Each SelectedRow In Items.AllUsers.SelectedRows Do
		DraggedItemsArray.Add(Items.AllUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(ShortListUsers, AllUsers, DraggedItemsArray);
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	SelectionResult = New ValueList;
	
	For Each CollectionItem In ShortListUsers Do
		SelectionResult.Add(CollectionItem.User);
	EndDo;
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillTables()
	SelectedItemsList = Parameters.UsersWithQuickAccess;
	Query = New Query("SELECT Ref FROM Catalog.Users WHERE NOT DeletionMark AND NOT Invalid AND NOT Internal");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If SelectedItemsList.FindByValue(Selection.Ref) = Undefined Then
			AllUsers.Add().User = Selection.Ref;
		Else
			ShortListUsers.Add().User = Selection.Ref;
		EndIf;
	EndDo;
	AllUsers.Sort("User Asc");
	ShortListUsers.Sort("User Asc");
EndProcedure

&AtClient
Procedure MoveUsers(Destination, Source, DraggedItemsArray)
	
	For Each ItemToDrag In DraggedItemsArray Do
		NewUser = Destination.Add();
		NewUser.User = ItemToDrag.User;
		Source.Delete(ItemToDrag);
	EndDo;
	
	Destination.Sort("User Asc");
	
EndProcedure

#EndRegion
