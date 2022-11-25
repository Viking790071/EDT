#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() = 1 Then
		Folder = Get(0).Folder;
		Path = Get(0).Path;
		
		If IsBlankString(Path) Then
			Return;
		EndIf;						
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FileFolders.Ref,
			|	FileFolders.Description
			|FROM
			|	Catalog.FileFolders AS FileFolders
			|WHERE
			|	FileFolders.Parent = &Ref";
		
		Query.SetParameter("Ref", Folder);
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			WorkingDirectory = Path;
			// Adding a slash to the end if it does not exist, the same type as it was before. It is required on 
			//  the client, and BeforeWrite is executed on the server.
			WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
			
			WorkingDirectory = WorkingDirectory + Selection.Description;
			WorkingDirectory = CommonClientServer.AddLastPathSeparator(WorkingDirectory);
			
			FilesOperationsInternalServerCall.SaveFolderWorkingDirectory(
				Selection.Ref, WorkingDirectory);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf