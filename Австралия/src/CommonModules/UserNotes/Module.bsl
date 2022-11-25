
////////////////////////////////////////////////////////////////////////////////
// Subsystem "User notes".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Marks notes for deletion which are associated with the object to be deleted.
Procedure MarkToDeleteSubjectNotes(Source, Cancel) Export
	If Not Source.DeletionMark Then
		Return;
	EndIf;
	
	QueryText =
	"SELECT
	|	Notes.Ref AS Ref
	|FROM
	|	Catalog.Notes AS Notes
	|WHERE
	|	Notes.DeletionMark = FALSE
	|	AND Notes.Subject = &Subject";
	
	Query = New Query(QueryText);
	Query.SetParameter("Subject", Source.Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NoteObject = Selection.Ref.GetObject();
		NoteObject.SetDeletionMark(True, False);
		NoteObject.AdditionalProperties.Insert("NoteDeletionMark", True);
		Try
			NoteObject.Write();
		Except
			ErrorText = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("en = 'User notes.Set deletion mark'; ru = 'Заметки пользователя.Установка пометки удаления';pl = 'Notatki użytkownika.Wskaż usunięcie';es_ES = 'Notas de usuario.Establecer la marca de borrado';es_CO = 'Notas de usuario.Establecer la marca de borrado';tr = 'Kullanıcı notları. Silme işaretini ayarla';it = 'Note utente. Imposta il contrassegno per eliminazione';de = 'Benutzerhinweise. Löschmarkierung setzen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, NoteObject.Metadata(), NoteObject.Ref, ErrorText);
		EndTry;
	EndDo;
EndProcedure

#EndRegion
