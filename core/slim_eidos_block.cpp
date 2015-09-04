//
//  slim_script_block.cpp
//  SLiM
//
//  Created by Ben Haller on 6/7/15.
//  Copyright (c) 2015 Messer Lab, http://messerlab.org/software/. All rights reserved.
//

#include "slim_eidos_block.h"
#include "eidos_interpreter.h"
#include "slim_global.h"
#include "eidos_call_signature.h"
#include "eidos_property_signature.h"
#include "eidos_ast_node.h"

#include "errno.h"


using std::endl;
using std::string;


//
//	SLiMEidosScript
//
#pragma mark SLiMEidosScript

SLiMEidosScript::SLiMEidosScript(const string &p_script_string) : EidosScript(p_script_string)
{
}

SLiMEidosScript::~SLiMEidosScript(void)
{
}

EidosASTNode *SLiMEidosScript::Parse_SLiMFile(void)
{
	EidosToken *virtual_token = new EidosToken(EidosTokenType::kTokenContextFile, gEidosStr_empty_string, 0, 0);
	EidosASTNode *node = new EidosASTNode(virtual_token, true);
	
	while (current_token_type_ != EidosTokenType::kTokenEOF)
	{
		// We handle the grammar a bit differently than how it is printed in the railroad diagrams in the doc.
		// Parsing of the optional generation range is done in Parse_SLiMEidosBlock() since it ends up as children of that node.
		EidosASTNode *script_block = Parse_SLiMEidosBlock();
		
		node->AddChild(script_block);
	}
	
	Match(EidosTokenType::kTokenEOF, "SLiM file");
	
	return node;
}

EidosASTNode *SLiMEidosScript::Parse_SLiMEidosBlock(void)
{
	EidosToken *virtual_token = new EidosToken(EidosTokenType::kTokenContextEidosBlock, gEidosStr_empty_string, 0, 0);
	EidosASTNode *slim_script_block_node = new EidosASTNode(virtual_token, true);
	
	// We handle the grammar a bit differently than how it is printed in the railroad diagrams in the doc.
	// We parse the slim_script_info section here, as part of the script block.
	
	// The first element is an optional script identifier like s1; we check here that an identifier matches the
	// pattern sX before eating it, since an identifier here could also be a callback tag like "fitness".
	if ((current_token_type_ == EidosTokenType::kTokenIdentifier) && SLiMEidosScript::StringIsIDWithPrefix(current_token_->token_string_, 's'))
	{
		// a script identifier like s1 is present; add it
		EidosASTNode *script_id_node = new EidosASTNode(current_token_);
		
		Match(EidosTokenType::kTokenIdentifier, "SLiM script block");
		slim_script_block_node->AddChild(script_id_node);
	}
	
	// Next comes an optional generation X or generation range X:Y
	if (current_token_type_ == EidosTokenType::kTokenNumber)
	{
		// A start generation is present; add it
		EidosASTNode *start_generation_node = Parse_Constant();
		
		slim_script_block_node->AddChild(start_generation_node);
		
		if (current_token_type_ == EidosTokenType::kTokenColon)
		{
			// An end generation is present; add it
			Match(EidosTokenType::kTokenColon, "SLiM script block");
			
			if (current_token_type_ == EidosTokenType::kTokenNumber)
			{
				EidosASTNode *end_generation_node = Parse_Constant();
				
				slim_script_block_node->AddChild(end_generation_node);
			}
			else
			{
				EIDOS_TERMINATION << "ERROR (SLiMEidosScript::Parse_SLiMEidosBlock): unexpected token " << *current_token_ << "; expected an integer for the generation range end." << eidos_terminate(current_token_);
			}
		}
	}
	
	// Now we are to the point of parsing the actual slim_script_block
	if (current_token_type_ == EidosTokenType::kTokenIdentifier)
	{
		if (current_token_->token_string_.compare(gStr_initialize) == 0)
		{
			EidosASTNode *callback_info_node = new EidosASTNode(current_token_);
			
			Match(EidosTokenType::kTokenIdentifier, "SLiM initialize() callback");
			Match(EidosTokenType::kTokenLParen, "SLiM initialize() callback");
			Match(EidosTokenType::kTokenRParen, "SLiM initialize() callback");
			
			slim_script_block_node->AddChild(callback_info_node);
		}
		else if (current_token_->token_string_.compare(gStr_fitness) == 0)
		{
			EidosASTNode *callback_info_node = new EidosASTNode(current_token_);
			
			Match(EidosTokenType::kTokenIdentifier, "SLiM fitness() callback");
			Match(EidosTokenType::kTokenLParen, "SLiM fitness() callback");
			
			if (current_token_type_ == EidosTokenType::kTokenIdentifier)
			{
				// A (required) mutation type id is present; add it
				EidosASTNode *mutation_type_id_node = new EidosASTNode(current_token_);
				
				Match(EidosTokenType::kTokenIdentifier, "SLiM fitness() callback");
				callback_info_node->AddChild(mutation_type_id_node);
			}
			else
			{
				EIDOS_TERMINATION << "ERROR (SLiMEidosScript::Parse_SLiMEidosBlock): unexpected token " << *current_token_ << "; a mutation type id is required in fitness() callback definitions." << eidos_terminate(current_token_);
			}
			
			if (current_token_type_ == EidosTokenType::kTokenComma)
			{
				// A (optional) subpopulation id is present; add it
				Match(EidosTokenType::kTokenComma, "SLiM fitness() callback");
				
				if (current_token_type_ == EidosTokenType::kTokenIdentifier)
				{
					EidosASTNode *subpopulation_id_node = new EidosASTNode(current_token_);
					
					Match(EidosTokenType::kTokenIdentifier, "SLiM fitness() callback");
					callback_info_node->AddChild(subpopulation_id_node);
				}
				else
				{
					EIDOS_TERMINATION << "ERROR (SLiMEidosScript::Parse_SLiMEidosBlock): unexpected token " << *current_token_ << "; subpopulation id expected." << eidos_terminate(current_token_);
				}
			}
			
			Match(EidosTokenType::kTokenRParen, "SLiM fitness() callback");
			
			slim_script_block_node->AddChild(callback_info_node);
		}
		else if (current_token_->token_string_.compare(gStr_mateChoice) == 0)
		{
			EidosASTNode *callback_info_node = new EidosASTNode(current_token_);
			
			Match(EidosTokenType::kTokenIdentifier, "SLiM mateChoice() callback");
			Match(EidosTokenType::kTokenLParen, "SLiM mateChoice() callback");
			
			// A (optional) subpopulation id is present; add it
			if (current_token_type_ == EidosTokenType::kTokenIdentifier)
			{
				EidosASTNode *subpopulation_id_node = new EidosASTNode(current_token_);
				
				Match(EidosTokenType::kTokenIdentifier, "SLiM mateChoice() callback");
				callback_info_node->AddChild(subpopulation_id_node);
			}
			
			Match(EidosTokenType::kTokenRParen, "SLiM mateChoice() callback");
			
			slim_script_block_node->AddChild(callback_info_node);
		}
		else if (current_token_->token_string_.compare(gStr_modifyChild) == 0)
		{
			EidosASTNode *callback_info_node = new EidosASTNode(current_token_);
			
			Match(EidosTokenType::kTokenIdentifier, "SLiM modifyChild() callback");
			Match(EidosTokenType::kTokenLParen, "SLiM modifyChild() callback");
			
			// A (optional) subpopulation id is present; add it
			if (current_token_type_ == EidosTokenType::kTokenIdentifier)
			{
				EidosASTNode *subpopulation_id_node = new EidosASTNode(current_token_);
				
				Match(EidosTokenType::kTokenIdentifier, "SLiM modifyChild() callback");
				callback_info_node->AddChild(subpopulation_id_node);
			}
			
			Match(EidosTokenType::kTokenRParen, "SLiM modifyChild() callback");
			
			slim_script_block_node->AddChild(callback_info_node);
		}
		else
		{
			EIDOS_TERMINATION << "ERROR (SLiMEidosScript::Parse_SLiMEidosBlock): unexpected identifier " << *current_token_ << "; expected a callback declaration (initialize, fitness, mateChoice, or modifyChild) or a compound statement." << eidos_terminate(current_token_);
		}
	}
	
	// Regardless of what happened above, all Eidos blocks end with a compound statement, which is the last child of the node
	EidosASTNode *compound_statement_node = Parse_CompoundStatement();
	
	slim_script_block_node->AddChild(compound_statement_node);
	
	return slim_script_block_node;
}

void SLiMEidosScript::ParseSLiMFileToAST(void)
{
	// delete the existing AST
	delete parse_root_;
	parse_root_ = nullptr;
	
	// set up parse state
	parse_index_ = 0;
	current_token_ = token_stream_.at(parse_index_);		// should always have at least an EOF
	current_token_type_ = current_token_->token_type_;
	
	// parse a new AST from our start token
	EidosASTNode *tree = Parse_SLiMFile();
	
	tree->OptimizeTree();
	
	parse_root_ = tree;
	
	// if logging of the AST is requested, do that
	if (gEidosLogAST)
	{
		std::cout << "AST : \n";
		this->PrintAST(std::cout);
	}
}

bool SLiMEidosScript::StringIsIDWithPrefix(const string &p_identifier_string, char p_prefix_char)
{
	const char *id_cstr = p_identifier_string.c_str();
	size_t id_cstr_len = strlen(id_cstr);
	
	// the criteria here are pretty loose, because we want SLiMEidosScript::ExtractIDFromStringWithPrefix to be
	// called and generate a raise if the string appears to be intended to be an ID but is malformed
	if ((id_cstr_len < 1) || (*id_cstr != p_prefix_char))
		return false;
	
	return true;
}

slim_objectid_t SLiMEidosScript::ExtractIDFromStringWithPrefix(const string &p_identifier_string, char p_prefix_char, const EidosToken *p_blame_token)
{
	const char *id_cstr = p_identifier_string.c_str();
	size_t id_cstr_len = strlen(id_cstr);
	
	if ((id_cstr_len < 1) || (*id_cstr != p_prefix_char))
		EIDOS_TERMINATION << "ERROR (SLiMEidosScript::ExtractIDFromStringWithPrefix): an identifier prefix \"" << p_prefix_char << "\" was expected." << eidos_terminate(p_blame_token);
	
	for (int str_index = 1; str_index < id_cstr_len; ++str_index)
		if ((id_cstr[str_index] < '0') || (id_cstr[str_index] > '9'))
			EIDOS_TERMINATION << "ERROR (SLiMEidosScript::ExtractIDFromStringWithPrefix): the id after the \"" << p_prefix_char << "\" prefix must be a simple integer." << eidos_terminate(p_blame_token);
	
	if (id_cstr_len < 2)
		EIDOS_TERMINATION << "ERROR (SLiMEidosScript::ExtractIDFromStringWithPrefix): an integer id was expected after the \"" << p_prefix_char << "\" prefix." << eidos_terminate(p_blame_token);
	
	errno = 0;
	char *end_scan_char = nullptr;
	int64_t long_block_id = strtoq(id_cstr + 1, &end_scan_char, 10);	// +1 to omit the prefix character
	
	if (errno || (end_scan_char == id_cstr + 1))
		EIDOS_TERMINATION << "ERROR (SLiMEidosScript::ExtractIDFromStringWithPrefix): the identifier " << p_identifier_string << " was not parseable." << eidos_terminate(p_blame_token);
	
	if ((long_block_id < 0) || (long_block_id > SLIM_MAX_ID_VALUE))
		EIDOS_TERMINATION << "ERROR (SLiMEidosScript::ExtractIDFromStringWithPrefix): the identifier " << p_identifier_string << " was out of range." << eidos_terminate(p_blame_token);
	
	return static_cast<slim_objectid_t>(long_block_id);		// range check is above, with a better message than SLiMCastToObjectidTypeOrRaise()
}


//
//	SLiMEidosBlock
//
#pragma mark -
#pragma mark SLiMEidosBlock

SLiMEidosBlock::SLiMEidosBlock(EidosASTNode *p_root_node) : root_node_(p_root_node)
{
	const std::vector<EidosASTNode *> &block_children = root_node_->children_;
	int child_index = 0, n_children = (int)block_children.size();
	
	// eat a string, for the script id, if present; an identifier token must follow the sX format to be taken as an id here, as in the parse code
	block_id_ = -1;	// the default unless it is set below
	
	if (child_index < n_children)
	{
		EidosToken *script_id_token = block_children[child_index]->token_;
		
		if ((script_id_token->token_type_ == EidosTokenType::kTokenIdentifier) && SLiMEidosScript::StringIsIDWithPrefix(script_id_token->token_string_, 's'))
		{
			block_id_ = SLiMEidosScript::ExtractIDFromStringWithPrefix(script_id_token->token_string_, 's', script_id_token);
			child_index++;
		}
	}
	
	// eat a number, for the start generation, if present
	if (child_index < n_children)
	{
		EidosToken *start_gen_token = block_children[child_index]->token_;
		
		if (start_gen_token->token_type_ == EidosTokenType::kTokenNumber)
		{
			int64_t long_start = EidosInterpreter::IntegerForString(start_gen_token->token_string_, start_gen_token);
			
			// We do our own range checking here so that we can highlight the bad token
			if ((long_start < 1) || (long_start > SLIM_MAX_GENERATION))
				EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): the start generation " << start_gen_token->token_string_ << " is out of range." << eidos_terminate(start_gen_token);
			
			start_generation_ = SLiMCastToGenerationTypeOrRaise(long_start);
			end_generation_ = start_generation_;			// if a start is given, the default end is the same as the start
			child_index++;
		}
	}
	
	// eat a number, for the end generation, if present
	if (child_index < n_children)
	{
		EidosToken *end_gen_token = block_children[child_index]->token_;
		
		if (end_gen_token->token_type_ == EidosTokenType::kTokenNumber)
		{
			int64_t long_end = EidosInterpreter::IntegerForString(end_gen_token->token_string_, end_gen_token);
			
			// We do our own range checking here so that we can highlight the bad token
			if ((long_end < 1) || (long_end > SLIM_MAX_GENERATION))
				EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): the end generation " << end_gen_token->token_string_ << " is out of range." << eidos_terminate(end_gen_token);
			if (long_end < start_generation_)
				EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): the end generation " << end_gen_token->token_string_ << " is less than the start generation." << eidos_terminate(end_gen_token);
			
			end_generation_ = SLiMCastToGenerationTypeOrRaise(long_end);
			child_index++;
		}
	}
	
	// eat the callback info node, if present
	if (child_index < n_children)
	{
		const EidosASTNode *callback_node = block_children[child_index];
		const EidosToken *callback_token = callback_node->token_;
		
		if (callback_token->token_type_ != EidosTokenType::kTokenLBrace)
		{
			EidosTokenType callback_type = callback_token->token_type_;
			const std::string &callback_name = callback_token->token_string_;
			const std::vector<EidosASTNode *> &callback_children = callback_node->children_;
			int n_callback_children = (int)callback_children.size();
			
			identifier_token_ = callback_token;	// remember our identifier token for easy access later
			
			if ((callback_type == EidosTokenType::kTokenIdentifier) && (callback_name.compare(gStr_initialize) == 0))
			{
				if (n_callback_children != 0)
					EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): initialize() callback needs 0 parameters." << eidos_terminate(callback_token);
				
				if ((start_generation_ != -1) || (end_generation_ != SLIM_MAX_GENERATION))
					EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): a generation range cannot be specified for an initialize() callback." << eidos_terminate(callback_token);
				
				start_generation_ = 0;
				end_generation_ = 0;
				type_ = SLiMEidosBlockType::SLiMEidosInitializeCallback;
			}
			else if ((callback_type == EidosTokenType::kTokenIdentifier) && (callback_name.compare(gStr_fitness) == 0))
			{
				if ((n_callback_children != 1) && (n_callback_children != 2))
					EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): fitness() callback needs 1 or 2 parameters." << eidos_terminate(callback_token);
				
				EidosToken *mutation_type_id_token = callback_children[0]->token_;
				
				mutation_type_id_ = SLiMEidosScript::ExtractIDFromStringWithPrefix(mutation_type_id_token->token_string_, 'm', mutation_type_id_token);
				
				if (n_callback_children == 2)
				{
					EidosToken *subpop_id_token = callback_children[1]->token_;
					
					subpopulation_id_ = SLiMEidosScript::ExtractIDFromStringWithPrefix(subpop_id_token->token_string_, 'p', subpop_id_token);
				}
				
				type_ = SLiMEidosBlockType::SLiMEidosFitnessCallback;
			}
			else if ((callback_type == EidosTokenType::kTokenIdentifier) && (callback_name.compare(gStr_mateChoice) == 0))
			{
				if ((n_callback_children != 0) && (n_callback_children != 1))
					EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): mateChoice() callback needs 0 or 1 parameters." << eidos_terminate(callback_token);
				
				if (n_callback_children == 1)
				{
					EidosToken *subpop_id_token = callback_children[0]->token_;
					
					subpopulation_id_ = SLiMEidosScript::ExtractIDFromStringWithPrefix(subpop_id_token->token_string_, 'p', subpop_id_token);
				}
				
				type_ = SLiMEidosBlockType::SLiMEidosMateChoiceCallback;
			}
			else if ((callback_type == EidosTokenType::kTokenIdentifier) && (callback_name.compare(gStr_modifyChild) == 0))
			{
				if ((n_callback_children != 0) && (n_callback_children != 1))
					EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): modifyChild() callback needs 0 or 1 parameters." << eidos_terminate(callback_token);
				
				if (n_callback_children == 1)
				{
					EidosToken *subpop_id_token = callback_children[0]->token_;
					
					subpopulation_id_ = SLiMEidosScript::ExtractIDFromStringWithPrefix(subpop_id_token->token_string_, 'p', subpop_id_token);
				}
				
				type_ = SLiMEidosBlockType::SLiMEidosModifyChildCallback;
			}
			else
			{
				EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): unknown callback type." << eidos_terminate(callback_token);
			}
			
			child_index++;
		}
	}
	
	// eat the compound statement, which must be present
	if ((child_index < n_children) && (block_children[child_index]->token_->token_type_ == EidosTokenType::kTokenLBrace))
	{
		compound_statement_node_ = block_children[child_index];
		child_index++;
	}
	
	if (!compound_statement_node_)
		EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): no compound statement found for SLiMEidosBlock." << eidos_terminate(child_index > 0 ? block_children[child_index - 1]->token_ : nullptr);
	
	if (child_index != n_children)
		EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): unexpected node in SLiMEidosBlock." << eidos_terminate(block_children[child_index]->token_);
	
	ScanTreeForIdentifiersUsed();
}

SLiMEidosBlock::SLiMEidosBlock(slim_objectid_t p_id, const std::string &p_script_string, SLiMEidosBlockType p_type, slim_generation_t p_start, slim_generation_t p_end)
	: block_id_(p_id), type_(p_type), start_generation_(p_start), end_generation_(p_end)
{
	script_ = new EidosScript(p_script_string);

	script_->Tokenize();
	script_->ParseInterpreterBlockToAST();
	
	root_node_ = script_->AST();
	
	if (root_node_->children_.size() != 1)
		EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): script blocks must be compound statements." << eidos_terminate();
	if (root_node_->children_[0]->token_->token_type_ != EidosTokenType::kTokenLBrace)
		EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::SLiMEidosBlock): script blocks must be compound statements." << eidos_terminate();
	
	compound_statement_node_ = root_node_->children_[0];
	
	ScanTreeForIdentifiersUsed();
}

SLiMEidosBlock::~SLiMEidosBlock(void)
{
	delete script_;
	
	if (self_symbol_)
	{
		delete self_symbol_->second;
		delete self_symbol_;
	}
	if (script_block_symbol_)
	{
		delete script_block_symbol_->second;
		delete script_block_symbol_;
	}
	
	if (cached_value_block_id_)
		delete cached_value_block_id_;
}

void SLiMEidosBlock::_ScanNodeForIdentifiersUsed(const EidosASTNode *p_scan_node)
{
	// recurse down the tree; determine our children, then ourselves
	for (auto child : p_scan_node->children_)
		_ScanNodeForIdentifiersUsed(child);
	
	if (p_scan_node->token_->token_type_ == EidosTokenType::kTokenIdentifier)
	{
		const std::string &token_string = p_scan_node->token_->token_string_;
		
		if (token_string.compare(gEidosStr_executeLambda) == 0)		contains_wildcard_ = true;
		if (token_string.compare(gEidosStr_ls) == 0)				contains_wildcard_ = true;
		if (token_string.compare(gEidosStr_rm) == 0)				contains_wildcard_ = true;
		
		// ***** If a new flag is added here, it must also be added to the list in SLiMEidosBlock::ScanTree!
		
		if (token_string.compare(gEidosStr_T) == 0)					eidos_contains_.contains_T_ = true;
		if (token_string.compare(gEidosStr_F) == 0)					eidos_contains_.contains_F_ = true;
		if (token_string.compare(gEidosStr_NULL) == 0)				eidos_contains_.contains_NULL_ = true;
		if (token_string.compare(gEidosStr_PI) == 0)					eidos_contains_.contains_PI_ = true;
		if (token_string.compare(gEidosStr_E) == 0)					eidos_contains_.contains_E_ = true;
		if (token_string.compare(gEidosStr_INF) == 0)				eidos_contains_.contains_INF_ = true;
		if (token_string.compare(gEidosStr_NAN) == 0)				eidos_contains_.contains_NAN_ = true;
		
		// look for instance identifiers like p1, g1, m1, s1; the heuristic here is very dumb, but errs on the safe side
		if (token_string.length() >= 2)
		{
			char char2 = token_string[1];
			
			if ((char2 >= '0') && (char2 <= '9'))
			{
				char char1 = token_string[0];
				
				if (char1 == 'p')								contains_pX_ = true;
				if (char1 == 'g')								contains_gX_ = true;
				if (char1 == 'm')								contains_mX_ = true;
				if (char1 == 's')								contains_sX_ = true;
			}
		}
		
		if (token_string.compare(gStr_sim) == 0)				contains_sim_ = true;
		if (token_string.compare(gStr_self) == 0)				contains_self_ = true;
		
		if (token_string.compare(gStr_mut) == 0)				contains_mut_ = true;
		if (token_string.compare(gStr_relFitness) == 0)			contains_relFitness_ = true;
		if (token_string.compare(gStr_genome1) == 0)			contains_genome1_ = true;
		if (token_string.compare(gStr_genome2) == 0)			contains_genome2_ = true;
		if (token_string.compare(gStr_subpop) == 0)				contains_subpop_ = true;
		if (token_string.compare(gStr_homozygous) == 0)			contains_homozygous_ = true;
		if (token_string.compare(gStr_sourceSubpop) == 0)		contains_sourceSubpop_ = true;
		if (token_string.compare(gStr_weights) == 0)			contains_weights_ = true;
		if (token_string.compare(gStr_childGenome1) == 0)		contains_childGenome1_ = true;
		if (token_string.compare(gStr_childGenome2) == 0)		contains_childGenome2_ = true;
		if (token_string.compare(gStr_childIsFemale) == 0)		contains_childIsFemale_ = true;
		if (token_string.compare(gStr_parent1Genome1) == 0)		contains_parent1Genome1_ = true;
		if (token_string.compare(gStr_parent1Genome2) == 0)		contains_parent1Genome2_ = true;
		if (token_string.compare(gStr_isCloning) == 0)			contains_isCloning_ = true;
		if (token_string.compare(gStr_isSelfing) == 0)			contains_isSelfing_ = true;
		if (token_string.compare(gStr_parent2Genome1) == 0)		contains_parent2Genome1_ = true;
		if (token_string.compare(gStr_parent2Genome2) == 0)		contains_parent2Genome2_ = true;
	}
}

void SLiMEidosBlock::ScanTreeForIdentifiersUsed(void)
{
	_ScanNodeForIdentifiersUsed(compound_statement_node_);
	
	// If the script block contains a "wildcard" – an identifier that signifies that any other identifier could be accessed – then
	// we just set all of our "contains_" flags to T.  Any new flag that is added must be added here too!
	if (contains_wildcard_)
	{
		eidos_contains_.contains_T_ = true;
		eidos_contains_.contains_F_ = true;
		eidos_contains_.contains_NULL_ = true;
		eidos_contains_.contains_PI_ = true;
		eidos_contains_.contains_E_ = true;
		eidos_contains_.contains_INF_ = true;
		eidos_contains_.contains_NAN_ = true;
		contains_pX_ = true;
		contains_gX_ = true;
		contains_mX_ = true;
		contains_sX_ = true;
		contains_sim_ = true;
		contains_self_ = true;
		contains_mut_ = true;
		contains_relFitness_ = true;
		contains_genome1_ = true;
		contains_genome2_ = true;
		contains_subpop_ = true;
		contains_homozygous_ = true;
		contains_sourceSubpop_ = true;
		contains_weights_ = true;
		contains_childGenome1_ = true;
		contains_childGenome2_ = true;
		contains_childIsFemale_ = true;
		contains_parent1Genome1_ = true;
		contains_parent1Genome2_ = true;
		contains_isCloning_ = true;
		contains_isSelfing_ = true;
		contains_parent2Genome1_ = true;
		contains_parent2Genome2_ = true;
	}
}


//
//	Eidos support
//
#pragma mark -
#pragma mark Eidos support

void SLiMEidosBlock::GenerateCachedSymbolTableEntry(void)
{
	// Note that this cache cannot be invalidated, because we are guaranteeing that this object will
	// live for at least as long as the symbol table it may be placed into!
	self_symbol_ = new EidosSymbolTableEntry(gStr_self, (new EidosValue_Object_singleton_const(this))->SetExternalPermanent());
}

void SLiMEidosBlock::GenerateCachedScriptBlockSymbolTableEntry(void)
{
	// Note that this cache cannot be invalidated, because we are guaranteeing that this object will
	// live for at least as long as the symbol table it may be placed into!
	if (block_id_ == -1)
		EIDOS_TERMINATION << "ERROR (SLiMEidosBlock::GenerateCachedScriptBlockSymbolTableEntry): (internal error) cached symbol table entries for anonymous script blocks are not supported." << eidos_terminate();
	
	std::ostringstream script_stream;
	
	script_stream << "s" << block_id_;
	
	script_block_symbol_ = new EidosSymbolTableEntry(script_stream.str(), (new EidosValue_Object_singleton_const(this))->SetExternalPermanent());
}

const EidosObjectClass *SLiMEidosBlock::Class(void) const
{
	return gSLiM_SLiMEidosBlock_Class;
}

void SLiMEidosBlock::Print(std::ostream &p_ostream) const
{
	p_ostream << Class()->ElementType() << "<";
	
	if (start_generation_ > 0)
	{
		p_ostream << start_generation_;
		
		if (end_generation_ != start_generation_)
			p_ostream << ":" << end_generation_;
		
		p_ostream << " : ";
	}
	
	switch (type_)
	{
		case SLiMEidosBlockType::SLiMEidosEvent:				p_ostream << gStr_event; break;
		case SLiMEidosBlockType::SLiMEidosInitializeCallback:	p_ostream << gStr_initialize; break;
		case SLiMEidosBlockType::SLiMEidosFitnessCallback:		p_ostream << gStr_fitness; break;
		case SLiMEidosBlockType::SLiMEidosMateChoiceCallback:	p_ostream << gStr_mateChoice; break;
		case SLiMEidosBlockType::SLiMEidosModifyChildCallback:	p_ostream << gStr_modifyChild; break;
	}
	
	p_ostream << ">";
}

EidosValue *SLiMEidosBlock::GetProperty(EidosGlobalStringID p_property_id)
{
	// All of our strings are in the global registry, so we can require a successful lookup
	switch (p_property_id)
	{
			// constants
		case gID_id:
		{
			// Note that this cache cannot be invalidated, because we are guaranteeing that this object will
			// live for at least as long as the symbol table it may be placed into!
			if (!cached_value_block_id_)
				cached_value_block_id_ = (new EidosValue_Int_singleton_const(block_id_))->SetExternalPermanent();
			return cached_value_block_id_;
		}
		case gID_start:
			return new EidosValue_Int_singleton_const(start_generation_);
		case gID_end:
			return new EidosValue_Int_singleton_const(end_generation_);
		case gID_type:
		{
			switch (type_)
			{
				case SLiMEidosBlockType::SLiMEidosEvent:				return new EidosValue_String_singleton_const(gStr_event);
				case SLiMEidosBlockType::SLiMEidosInitializeCallback:	return new EidosValue_String_singleton_const(gStr_initialize);
				case SLiMEidosBlockType::SLiMEidosFitnessCallback:		return new EidosValue_String_singleton_const(gStr_fitness);
				case SLiMEidosBlockType::SLiMEidosMateChoiceCallback:	return new EidosValue_String_singleton_const(gStr_mateChoice);
				case SLiMEidosBlockType::SLiMEidosModifyChildCallback:	return new EidosValue_String_singleton_const(gStr_modifyChild);
			}
		}
		case gID_source:
			return new EidosValue_String_singleton_const(compound_statement_node_->token_->token_string_);
			
			// variables
		case gID_active:
			return new EidosValue_Int_singleton_const(active_);
		case gID_tag:
			return new EidosValue_Int_singleton_const(tag_value_);
			
			// all others, including gID_none
		default:
			return EidosObjectElement::GetProperty(p_property_id);
	}
}

void SLiMEidosBlock::SetProperty(EidosGlobalStringID p_property_id, EidosValue *p_value)
{
	switch (p_property_id)
	{
		case gID_active:
		{
			active_ = SLiMCastToUsertagTypeOrRaise(p_value->IntAtIndex(0, nullptr));
			
			return;
		}
	
		case gID_tag:
		{
			slim_usertag_t value = SLiMCastToUsertagTypeOrRaise(p_value->IntAtIndex(0, nullptr));
			
			tag_value_ = value;
			return;
		}
			
			// all others, including gID_none
		default:
			return EidosObjectElement::SetProperty(p_property_id, p_value);
	}
}

EidosValue *SLiMEidosBlock::ExecuteInstanceMethod(EidosGlobalStringID p_method_id, EidosValue *const *const p_arguments, int p_argument_count, EidosInterpreter &p_interpreter)
{
	return EidosObjectElement::ExecuteInstanceMethod(p_method_id, p_arguments, p_argument_count, p_interpreter);
}


//
//	SLiMEidosBlock_Class
//
#pragma mark -
#pragma mark SLiMEidosBlock_Class

class SLiMEidosBlock_Class : public EidosObjectClass
{
public:
	SLiMEidosBlock_Class(const SLiMEidosBlock_Class &p_original) = delete;	// no copy-construct
	SLiMEidosBlock_Class& operator=(const SLiMEidosBlock_Class&) = delete;	// no copying
	
	SLiMEidosBlock_Class(void);
	
	virtual const std::string &ElementType(void) const;
	
	virtual const std::vector<const EidosPropertySignature *> *Properties(void) const;
	virtual const EidosPropertySignature *SignatureForProperty(EidosGlobalStringID p_property_id) const;
	
	virtual const std::vector<const EidosMethodSignature *> *Methods(void) const;
	virtual const EidosMethodSignature *SignatureForMethod(EidosGlobalStringID p_method_id) const;
	virtual EidosValue *ExecuteClassMethod(EidosGlobalStringID p_method_id, EidosValue *const *const p_arguments, int p_argument_count, EidosInterpreter &p_interpreter) const;
};

EidosObjectClass *gSLiM_SLiMEidosBlock_Class = new SLiMEidosBlock_Class();


SLiMEidosBlock_Class::SLiMEidosBlock_Class(void)
{
}

const std::string &SLiMEidosBlock_Class::ElementType(void) const
{
	return gStr_SLiMEidosBlock;
}

const std::vector<const EidosPropertySignature *> *SLiMEidosBlock_Class::Properties(void) const
{
	static std::vector<const EidosPropertySignature *> *properties = nullptr;
	
	if (!properties)
	{
		properties = new std::vector<const EidosPropertySignature *>(*EidosObjectClass::Properties());
		properties->push_back(SignatureForPropertyOrRaise(gID_id));
		properties->push_back(SignatureForPropertyOrRaise(gID_start));
		properties->push_back(SignatureForPropertyOrRaise(gID_end));
		properties->push_back(SignatureForPropertyOrRaise(gID_type));
		properties->push_back(SignatureForPropertyOrRaise(gID_source));
		properties->push_back(SignatureForPropertyOrRaise(gID_active));
		properties->push_back(SignatureForPropertyOrRaise(gID_tag));
		std::sort(properties->begin(), properties->end(), CompareEidosPropertySignatures);
	}
	
	return properties;
}

const EidosPropertySignature *SLiMEidosBlock_Class::SignatureForProperty(EidosGlobalStringID p_property_id) const
{
	// Signatures are all preallocated, for speed
	static EidosPropertySignature *idSig = nullptr;
	static EidosPropertySignature *startSig = nullptr;
	static EidosPropertySignature *endSig = nullptr;
	static EidosPropertySignature *typeSig = nullptr;
	static EidosPropertySignature *sourceSig = nullptr;
	static EidosPropertySignature *activeSig = nullptr;
	static EidosPropertySignature *tagSig = nullptr;
	
	if (!idSig)
	{
		idSig =			(EidosPropertySignature *)(new EidosPropertySignature(gStr_id,		gID_id,			true,	kEidosValueMaskInt | kEidosValueMaskSingleton));
		startSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_start,	gID_start,		true,	kEidosValueMaskInt | kEidosValueMaskSingleton));
		endSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_end,		gID_end,		true,	kEidosValueMaskInt | kEidosValueMaskSingleton));
		typeSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_type,	gID_type,		true,	kEidosValueMaskString | kEidosValueMaskSingleton));
		sourceSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_source,	gID_source,		true,	kEidosValueMaskString | kEidosValueMaskSingleton));
		activeSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_active,	gID_active,		false,	kEidosValueMaskInt | kEidosValueMaskSingleton));
		tagSig =		(EidosPropertySignature *)(new EidosPropertySignature(gStr_tag,		gID_tag,		false,	kEidosValueMaskInt | kEidosValueMaskSingleton));
	}
	
	// All of our strings are in the global registry, so we can require a successful lookup
	switch (p_property_id)
	{
		case gID_id:		return idSig;
		case gID_start:		return startSig;
		case gID_end:		return endSig;
		case gID_type:		return typeSig;
		case gID_source:	return sourceSig;
		case gID_active:	return activeSig;
		case gID_tag:		return tagSig;
			
			// all others, including gID_none
		default:
			return EidosObjectClass::SignatureForProperty(p_property_id);
	}
}

const std::vector<const EidosMethodSignature *> *SLiMEidosBlock_Class::Methods(void) const
{
	std::vector<const EidosMethodSignature *> *methods = nullptr;
	
	if (!methods)
	{
		methods = new std::vector<const EidosMethodSignature *>(*EidosObjectClass::Methods());
		std::sort(methods->begin(), methods->end(), CompareEidosCallSignatures);
	}
	
	return methods;
}

const EidosMethodSignature *SLiMEidosBlock_Class::SignatureForMethod(EidosGlobalStringID p_method_id) const
{
	return EidosObjectClass::SignatureForMethod(p_method_id);
}

EidosValue *SLiMEidosBlock_Class::ExecuteClassMethod(EidosGlobalStringID p_method_id, EidosValue *const *const p_arguments, int p_argument_count, EidosInterpreter &p_interpreter) const
{
	return EidosObjectClass::ExecuteClassMethod(p_method_id, p_arguments, p_argument_count, p_interpreter);
}





























































