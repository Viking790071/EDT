
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	RefreshSearchHistory(Items.SearchString);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunSearch(Command)
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("ru = 'Введите, что нужно найти.'; en = 'Enter a search text.'; pl = 'Wprowadź obiekt wyszukiwania.';es_ES = 'Introducir un objeto de búsqueda.';es_CO = 'Introducir un objeto de búsqueda.';tr = 'Bulunması gerekeni girin';it = 'Inserisci un testo di ricerca.';de = 'Geben Sie ein Suchobjekt ein.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("PassedSearchString", SearchString);
	
	OpenForm("CommonForm.SearchForm", FormParameters,, True);
	
	RefreshSearchHistory(Items.SearchString);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure RefreshSearchHistory(Item)
	
	SearchHistory = SavedSearchHistory();
	If TypeOf(SearchHistory) = Type("Array") Then
		Item.ChoiceList.LoadValues(SearchHistory);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SavedSearchHistory()
	
	Return Common.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings", "");
	
EndFunction

#EndRegion
