#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	AttributesToExclude = New Array;
	
	If Not Custom Then
		AttributesToExclude.Add("Author");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	
	If Description <> "" AND ReportsOptions.DescriptionIsUsed(Report, Ref, Description) Then
		Cancel = True;
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '""%1"" занято, необходимо указать другое наименование.'; en = '""%1"" is already used, enter another name.'; pl = '""%1"" jest już używane, wprowadź inną nazwę.';es_ES = '""%1"" ya está utilizado, introducir otro nombre.';es_CO = '""%1"" ya está utilizado, introducir otro nombre.';tr = '""%1"" zaten kullanılmakta, başka bir ad girin.';it = '""%1"" è già utilizzato, immettere un altro nome.';de = '""%1"" wird bereits verwendet, geben Sie einen anderen Namen ein.'"), Description),
			,
			"Description");
	EndIf;
EndProcedure

Procedure BeforeWrite(Cancel)
	If AdditionalProperties.Property("PredefinedObjectsFilling") Then
		CheckFillingOfPredefined(Cancel);
	EndIf;
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
	UserChangedDeletionMark = (
		Not IsNew()
		AND DeletionMark <> Ref.DeletionMark
		AND Not AdditionalProperties.Property("PredefinedObjectsFilling"));
	
	If Not Custom AND UserChangedDeletionMark Then
		If DeletionMark Then
			ErrorText = NStr("ru = 'Пометка на удаление предопределенного варианта отчета запрещена.'; en = 'Cannot mark a predefined report option for deletion.'; pl = 'Nie można zaznaczyć predefiniowanej opcji sprawozdania do usunięcia.';es_ES = 'No se puede marcar la opción del informe predefinido para borrar.';es_CO = 'No se puede marcar la opción del informe predefinido para borrar.';tr = 'Öntanımlı rapor seçeneği silinmek üzere işaretlenemez.';it = 'Non è possibile contrassegnare per l''eliminazione un variante di report predefinita.';de = 'Die vordefinierte Berichtsoption kann nicht zum Löschen markiert werden.'");
		Else
			ErrorText = NStr("ru = 'Снятие пометки удаления предопределенного варианта отчета запрещена.'; en = 'Cannot unmark the predefined report option for deletion.'; pl = 'Nie można usunąć znacznika usunięcia predefiniowanej opcji sprawozdania.';es_ES = 'No se puede desmarcar la opción de un informe predefinido para borrar.';es_CO = 'No se puede desmarcar la opción de un informe predefinido para borrar.';tr = 'Öntanımlı rapor seçeneğinin silme işareti kaldırılamaz.';it = 'Non è possibile cancellare il contrassegno per l''eliminazione dalla variante di report predefinita';de = 'Die vordefinierte Berichtsoption kann nicht zum Löschen entfernt werden.'");
		EndIf;
		Raise ErrorText;
	EndIf;
	
	If Not DeletionMark AND UserChangedDeletionMark Then
		DescriptionIsUsed = ReportsOptions.DescriptionIsUsed(Report, Ref, Description);
		OptionKeyIsUsed  = ReportsOptions.OptionKeyIsUsed(Report, Ref, VariantKey);
		If DescriptionIsUsed OR OptionKeyIsUsed Then
			ErrorText = NStr("ru = 'Ошибка снятия пометки удаления варианта отчета:'; en = 'An error occurred when clearing the deletion mark of report option:'; pl = 'Wystąpił błąd podczas usuwania znacznika usunięcia z opcji sprawozdania:';es_ES = 'Ha ocurrido un error al eliminar la marca de borrado de la opción del informe:';es_CO = 'Ha ocurrido un error al eliminar la marca de borrado de la opción del informe:';tr = 'Rapor seçeneğinin silme işareti kaldırılırken hata oluştu:';it = 'Un errore si è registrato durante la cancellazione del contrassegno per l''eliminazione della variante di report:';de = 'Beim Löschen der Löschmarkierung der Berichtsoption ist ein Fehler aufgetreten:'");
			If DescriptionIsUsed Then
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Наименование ""%1"" уже занято другим вариантом этого отчета.'; en = 'Name ""%1"" is already used by another option of this report.'; pl = 'Nazwa ""%1"" jest już używana przez inną opcję tego sprawozdania.';es_ES = 'Nombre ""%1"" ya está utilizado por otra opción de este informe.';es_CO = 'Nombre ""%1"" ya está utilizado por otra opción de este informe.';tr = '""%1"" adı, bu raporun başka bir seçeneği tarafından kullanılıyor.';it = 'Il nome ""%1"" è già usato da un''altra variante di questo report.';de = 'Der Name ""%1"" wird bereits von einer anderen Option dieses Berichts verwendet.'"),
					Description);
			Else
				ErrorText = ErrorText + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ключ варианта ""%1"" уже занят другим вариантом этого отчета.'; en = 'Key of option ""%1"" is already used by another option of this report.'; pl = 'Klucz opcji ""%1"" jest już używany przez inną opcję tego sprawozdania.';es_ES = 'Clave de la opción ""%1"" ya está utilizada por otra opción de este informe.';es_CO = 'Clave de la opción ""%1"" ya está utilizada por otra opción de este informe.';tr = '""%1"" seçeneğinin anahtarı, bu raporun başka bir seçeneği tarafından zaten kullanılıyor.';it = 'La chiave di variante ""%1"" è già usata da un''altra variante di questo report.';de = 'Der Schlüssel der Option ""%1"" wird bereits von einer anderen Option dieses Berichts verwendet.'"),
					VariantKey);
			EndIf;
			ErrorText = ErrorText + NStr("ru = 'Перед снятием пометки удаления варианта отчета
				|необходимо установить пометку удаления конфликтующего варианта отчета.'; 
				|en = 'Before unmarking report option for deletion,
				|mark the conflicting report option for deletion.'; 
				|pl = 'Przed usunięciem zaznaczenia do usunięcia
				|opcji raportu konieczne jest zaznaczenie konfliktującej opcji raportu do usunięcia.';
				|es_ES = 'Antes de desmarcar la marca de borrado
				|de la opción del informe, es necesario instalar la marca de borrado de la opción de un informe controversial.';
				|es_CO = 'Antes de desmarcar la marca de borrado
				|de la opción del informe, es necesario instalar la marca de borrado de la opción de un informe controversial.';
				|tr = 'Rapor seçeneğinin silme işaretini kaldırmadan önce,
				|çelişkili rapor seçeneğini silme için işaretleyin.';
				|it = 'Prima di deselezionare le opzioni di report per l''eliminazione, 
				|contrassegnare le opzioni di report in conflitto per l''eliminazione.';
				|de = 'Bevor Sie die Löschmarkierung
				|der Berichtsoption rückgängig machen ist es erforderlich, die Löschmarkierung der umstrittenen Berichtsoption zu installieren.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If UserChangedDeletionMark Then
		If Custom Then
			InteractiveSetDeletionMark = DeletionMark;
		Else
			InteractiveSetDeletionMark = False;
		EndIf;
	EndIf;
	
	// Delete subsystems marked for deletion from the tabular section.
	ArrayOfRowsToDelete = New Array;
	For Each PlacementRow In Placement Do
		If PlacementRow.Subsystem.DeletionMark = True Then
			ArrayOfRowsToDelete.Add(PlacementRow);
		EndIf;
	EndDo;
	For Each PlacementRow In ArrayOfRowsToDelete Do
		Placement.Delete(PlacementRow);
	EndDo;
	
	// Fill in FieldDescriptions and FilterParameterDescriptions attributes.
	IndexSettings();
EndProcedure

#EndRegion

#Region Private

Procedure IndexSettings()
	Additional = (ReportType = Enums.ReportTypes.Additional);
	If Not Custom AND Not Additional Then
		// Data for predefined report options are stored in a shared catalog.
		FieldDescriptions = "";
		FilterParameterDescriptions = "";
		Return;
	EndIf;
	If Additional AND SafeMode() = False Then
		Return; // Leave current settings.
	EndIf;
	Try
		ReportsOptions.IndexSchemaContent(ThisObject);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось проиндексировать схему варианта ""%1"" отчета ""%2"":'; en = 'Cannot index a scheme of option ""%1"" of report ""%2"":'; pl = 'Nie można indeksować schematu opcji ""%1"" sprawozdania ""%2"":';es_ES = 'No se puede indexar un esquema de la opción ""%1"" del informe ""%2"":';es_CO = 'No se puede indexar un esquema de la opción ""%1"" del informe ""%2"":';tr = '""%1"" raporunun ""%2"" seçeneğine ait şema endekslenemiyor:';it = 'Non è possibile indicizzare uno schema della variante ""%1"" del report ""%2"":';de = 'Ein Schema der Option ""%1"" des Berichts ""%2"" kann nicht indiziert werden:'"),
			VariantKey,
			String(Report));
		ErrorText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
		ReportsOptions.WriteToLog(EventLogLevel.Error, ErrorText, Ref);
	EndTry;
EndProcedure

// This procedure fills in a report option parent basing on the report reference and predefined settings.
Procedure FillInParent() Export
	QueryText =
	"SELECT ALLOWED TOP 1
	|	PredefinedReportsOptions.Ref AS PredefinedVariant
	|INTO ttPredefined
	|FROM
	|	Catalog.PredefinedReportsOptions AS PredefinedReportsOptions
	|WHERE
	|	PredefinedReportsOptions.Report = &Report
	|	AND PredefinedReportsOptions.DeletionMark = FALSE
	|	AND PredefinedReportsOptions.GroupByReport
	|
	|ORDER BY
	|	PredefinedReportsOptions.Enabled DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	ReportsOptions.Ref
	|FROM
	|	ttPredefined AS ttPredefined
	|		INNER JOIN Catalog.ReportsOptions AS ReportsOptions
	|		ON ttPredefined.PredefinedVariant = ReportsOptions.PredefinedVariant
	|WHERE
	|	ReportsOptions.DeletionMark = FALSE";
	If ReportType = Enums.ReportTypes.Extension Then
		QueryText = StrReplace(QueryText, ".PredefinedReportsOptions", ".PredefinedExtensionsReportsOptions");
	EndIf;
	Query = New Query;
	Query.SetParameter("Report", Report);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Parent = Selection.Ref;
	EndIf;
EndProcedure

// Basic validation of predefined report option data. 
Procedure CheckFillingOfPredefined(Cancel)
	If DeletionMark Or Not Predefined Then
		Return;
	ElsIf Not ValueIsFilled(Report) Then
		ErrorText = FieldIsNotFilledIn("Report");
	ElsIf Not ValueIsFilled(ReportType) Then
		ErrorText = FieldIsNotFilledIn("ReportType");
	ElsIf ReportType <> ReportsOptionsClientServer.ReportType(Report) Then
		ErrorText = NStr("ru = 'Противоречивые значения полей ""%1"" и ""%2""'; en = 'Inconsistent values of fields ""%1"" and ""%2""'; pl = 'Sprzeczne wartości pól ""%1"" i ""%2""';es_ES = 'Valores incompatibles de los campos ""%1"" y ""%2""';es_CO = 'Valores incompatibles de los campos ""%1"" y ""%2""';tr = '""%1"" ve ""%2"" alanlarının tutarsız değerleri';it = 'Valori del campo contraddittori ""%1"" e ""%2""';de = 'Inkonsistente Werte der Felder ""%1"" und ""%2""'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, "ReportType", "Report");
	ElsIf Not ValueIsFilled(PredefinedVariant)
		AND (ReportType = Enums.ReportTypes.Internal Or ReportType = Enums.ReportTypes.Extension) Then
		ErrorText = FieldIsNotFilledIn("PredefinedVariant");
	Else
		Return;
	EndIf;
	Raise ErrorText;
EndProcedure

Function FieldIsNotFilledIn(FieldName)
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не заполнено поле ""%1""'; en = 'The ""%1"" field is not filled in'; pl = 'Pole ""%1"" nie jest wypełnione';es_ES = 'El ""%1"" campo no está rellenado';es_CO = 'El ""%1"" campo no está rellenado';tr = '""%1"" alanı doldurulmadı';it = 'Il campo ""%1"" non è compilato';de = 'Das Feld ""%1"" ist nicht ausgefüllt'"), FieldName);
EndFunction

#EndRegion

#EndIf
