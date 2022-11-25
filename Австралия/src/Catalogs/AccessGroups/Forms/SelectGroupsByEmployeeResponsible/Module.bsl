
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Selected",                 Parameters.Selected);
	Query.SetParameter("GroupUser",         Parameters.GroupUser);
	Query.SetParameter("EmployeeResponsible",             Users.AuthorizedUser());
	Query.SetParameter("PersonResponsibleWithFullRights", Users.IsFullUser());
	
	SetPrivilegedMode(True);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Description AS Description,
	|	AccessGroups.IsFolder AS IsFolder,
	|	CASE
	|		WHEN AccessGroups.IsFolder
	|				AND NOT AccessGroups.DeletionMark
	|			THEN 0
	|		WHEN AccessGroups.IsFolder
	|				AND AccessGroups.DeletionMark
	|			THEN 1
	|		WHEN NOT AccessGroups.IsFolder
	|				AND NOT AccessGroups.DeletionMark
	|			THEN 3
	|		ELSE 4
	|	END AS PictureNumber,
	|	FALSE AS Check,
	|	AccessGroups.Comment AS Comment
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.IsFolder
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN (&Selected)
	|				THEN FALSE
	|			WHEN AccessGroups.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Profile.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators)
	|				THEN &PersonResponsibleWithFullRights
	|						AND VALUETYPE(&GroupUser) = TYPE(Catalog.Users)
	|			WHEN &PersonResponsibleWithFullRights = FALSE
	|					AND AccessGroups.EmployeeResponsible <> &EmployeeResponsible
	|				THEN FALSE
	|			ELSE CASE
	|						WHEN AccessGroups.User = UNDEFINED
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.Users.EmptyRef)
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|							THEN TRUE
	|						ELSE AccessGroups.User = &GroupUser
	|					END
	|					AND CASE
	|						WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.Users)
	|								OR VALUETYPE(&GroupUser) = TYPE(Catalog.UserGroups)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment
	|									WHERE
	|										AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = TYPE(Catalog.Users))
	|						WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.ExternalUsers)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment,
	|										Catalog.ExternalUsers AS ExternalUsers
	|									WHERE
	|										ExternalUsers.Ref = &GroupUser
	|										AND AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUsers.AuthorizationObject))
	|						WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.ExternalUsersGroups)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.AccessGroupProfiles.Purpose AS AccessGroupProfilesAssignment,
	|										Catalog.ExternalUsersGroups.Purpose AS ExternalUserGroupsAssignment
	|									WHERE
	|										ExternalUserGroupsAssignment.Ref = &GroupUser
	|										AND AccessGroupProfilesAssignment.Ref = AccessGroups.Profile
	|										AND VALUETYPE(AccessGroupProfilesAssignment.UsersType) = VALUETYPE(ExternalUserGroupsAssignment.UsersType))
	|						ELSE FALSE
	|					END
	|		END
	|
	|ORDER BY
	|	AccessGroups.Ref HIERARCHY";
	
	NewTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Folders = NewTree.Rows.FindRows(New Structure("IsFolder", True), True);
	
	DeleteFolders = New Map;
	NoFolders = True;
	
	For each Folder In Folders Do
		If Folder.Parent = Undefined
		   AND Folder.Rows.Count() = 0
		 OR Folder.Rows.FindRows(New Structure("IsFolder", False), True).Count() = 0 Then
			
			DeleteFolders.Insert(
				?(Folder.Parent = Undefined, NewTree.Rows, Folder.Parent.Rows),
				Folder);
		Else
			NoFolders = False;
		EndIf;
	EndDo;
	
	For each DeleteFolder In DeleteFolders Do
		If DeleteFolder.Key.IndexOf(DeleteFolder.Value) > -1 Then
			DeleteFolder.Key.Delete(DeleteFolder.Value);
		EndIf;
	EndDo;
	
	NewTree.Rows.Sort("IsFolder Desc, Description Asc", True);
	ValueToFormAttribute(NewTree, "AccessGroups");
	
	If NoFolders Then
		Items.AccessGroups.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessGroupsFormTableItemsEventHandlers

&AtClient
Procedure AccessGroupsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnChoice()
	
	CurrentData = Items.AccessGroups.CurrentData;
	
	If CurrentData <> Undefined Then
		If CurrentData.IsFolder Then
			
			If Items.AccessGroups.Expanded(Items.AccessGroups.CurrentRow) Then
				Items.AccessGroups.Collapse(Items.AccessGroups.CurrentRow);
			Else
				Items.AccessGroups.Expand(Items.AccessGroups.CurrentRow);
			EndIf;
		Else
			NotifyChoice(CurrentData.Ref);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
