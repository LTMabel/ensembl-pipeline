#!/usr/local/bin/perl

#
#
# Cared for by Michele Clamp  <michele@sanger.ac.uk>
#
# Copyright Michele Clamp
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::RunnableDB::AlignFeature

=head1 SYNOPSIS

    my $obj = Bio::EnsEMBL::Pipeline::RunnableDB::MiniGenewise->new(
					     -dbobj     => $db,
					     -input_id  => $id
                                             );
    $obj->fetch_input
    $obj->run

    my @newfeatures = $obj->output;


=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Pipeline::RunnableDB::FPC_BlastMiniGenewise;

use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::Object;
use Bio::EnsEMBL::Pipeline::RunnableDBI;
use Bio::EnsEMBL::Pipeline::Runnable::BlastMiniGenewise;
use Bio::EnsEMBL::Pipeline::GeneConf qw (EXON_ID_SUBSCRIPT
					 TRANSCRIPT_ID_SUBSCRIPT
					 GENE_ID_SUBSCRIPT
					 PROTEIN_ID_SUBSCRIPT
					 );

use Data::Dumper;

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDBI Bio::Root::Object );

sub _initialize {
    my ($self,@args) = @_;
    my $make = $self->SUPER::_initialize(@_);    
           
    my( $dbobj,$input_id ) = $self->_rearrange(['DBOBJ',
						'INPUT_ID'], @args);
       
    $self->throw("No database handle input")                 unless defined($dbobj);
    $self->dbobj($dbobj);

    $self->throw("No input id input") unless defined($input_id);
    $self->input_id($input_id);
    
    return $self; # success - we hope!
}
sub input_id {
	my ($self,$arg) = @_;

   if (defined($arg)) {
      $self->{_input_id} = $arg;
   }

   return $self->{_input_id};
}

=head2 dbobj

    Title   :   dbobj
    Usage   :   $self->dbobj($db)
    Function:   Get/set method for database handle
    Returns :   Bio::EnsEMBL::Pipeline::DB::ObjI
    Args    :   

=cut

sub dbobj {
    my( $self, $value ) = @_;    
    if ($value) {

        $value->isa("Bio::EnsEMBL::DB::ObjI") || $self->throw("Input [$value] isn't a Bio::EnsEMBL::DB::ObjI");
        $self->{'_dbobj'} = $value;
    }
    return $self->{'_dbobj'};
}

=head2 fetch_output

    Title   :   fetch_output
    Usage   :   $self->fetch_output($file_name);
    Function:   Fetchs output data from a frozen perl object
                stored in file $file_name
    Returns :   array of exons (with start and end)
    Args    :   none

=cut

sub fetch_output {
    my($self,$output) = @_;
    
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Writes output data to db
    Returns :   array of exons (with start and end)
    Args    :   none

=cut

sub write_output {
    my($self,@features) = @_;

    my $dblocator = "Bio::EnsEMBL::DBSQL::Obj/host=bcs121;dbname=simon_oct07;user=ensadmin";
    
    my $db = Bio::EnsEMBL::DBLoader->new($dblocator);
   
    if( !defined $db ) {
      $self->throw("unable to make write db");
    }
    
    my %contighash;
    my $gene_obj = $db->gene_Obj;

    # this now assummes that we are building on a single VC.


    my @newgenes = $self->output;
    return unless ($#newgenes >= 0);

    eval {

      GENE: foreach my $gene (@newgenes) {	

	    # do a per gene eval...
	    eval {

		my @exons = $gene->each_unique_Exon();

		next GENE if (scalar(@exons) == 1);
    
		$gene->type('genewise');
		
		my ($geneid) = $gene_obj->get_New_external_id('gene',$GENE_ID_SUBSCRIPT,1);
		
		$gene->id($geneid);
		print (STDERR "Writing gene " . $gene->id . "\n");
		
		# Convert all exon ids and save in a hash
		my %namehash;

		my @exonids = $gene_obj->get_New_external_id('exon',$EXON_ID_SUBSCRIPT,scalar(@exons));
		my $count = 0;
		foreach my $ex (@exons) {
		    $namehash{$ex->id} = $exonids[$count];
		    $ex->id($exonids[$count]);
		    print STDERR "Exon id is ".$ex->id."\n";
		    $count++;
		}
		
		my @transcripts = $gene->each_Transcript;
		my @transcript_ids = $gene_obj->get_New_external_id('transcript',$TRANSCRIPT_ID_SUBSCRIPT,scalar(@transcripts));
		my @translation_ids = $gene_obj->get_New_external_id('translation',$PROTEIN_ID_SUBSCRIPT,scalar(@transcripts));
		$count = 0;
		foreach my $tran (@transcripts) {
		    $tran->id             ($transcript_ids[$count]);
		    $tran->translation->id($translation_ids[$count]);
		    $count++;
		    
		    my $translation = $tran->translation;
		    
		    print (STDERR "Transcript  " . $tran->id . "\n");
		    print (STDERR "Translation " . $tran->translation->id . "\n");
		    
		    foreach my $ex ($tran->each_Exon) {
			my @sf = $ex->each_Supporting_Feature;
			print STDERR "Supporting features are " . scalar(@sf) . "\n";
			
			if ($namehash{$translation->start_exon_id} ne "") {
			    $translation->start_exon_id($namehash{$translation->start_exon_id});
			}
			if ($namehash{$translation->end_exon_id} ne "") {
			    $translation->end_exon_id  ($namehash{$translation->end_exon_id});
			}
			print(STDERR "Exon         " . $ex->id . "\n");
		    }
		    
		}
		
		$gene_obj->write($gene);
	    }; 
	    if( $@ ) {
		print STDERR "UNABLE TO WRITE GENE\n\n$@\n\nSkipping this gene\n";
	    }
	    
	}
    };
    if ($@) {

      $self->throw("Error writing gene for " . $self->input_id . " [$@]\n");
    } else {
      # nothing
    }


  }

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for est2genome from the database
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
    my( $self) = @_;
    
    print STDERR "Fetching input \n";
    $self->throw("No input id") unless defined($self->input_id);

    my $chrid  = $self->input_id;
       $chrid =~ s/\.(.*)-(.*)//;

    my $chrstart = $1;
    my $chrend   = $2;

    print STDERR "Chromosome id = $chrid , range $chrstart $chrend\n";

    $self->dbobj->static_golden_path_type('UCSC');

    my $stadaptor = $self->dbobj->get_StaticGoldenPathAdaptor();
    my $contig    = $stadaptor->fetch_VirtualContig_by_chr_start_end($chrid,$chrstart,$chrend);

    $contig->_chr_name($chrid);

    foreach my $rc ($contig->_vmap->each_MapContig) {
	my $strand = "+";
	if ($rc->orientation == -1) {
	    $strand = "-";
	}
	
	print STDERR $rc->contig->id . "\tsequence\t" . $rc->contig->id . "\t" . $rc->start . "\t" . $rc->end . "\t100\t" . $strand . "\t0\n";
    }

    my $genseq    = $contig->get_repeatmasked_seq;

    print STDERR "Length is " . $genseq->length . "\n";
    print STDERR "Fetching features \n";

    my @features  = $contig->get_all_SimilarityFeatures_above_score('sptr',200);
    
    print STDERR "Number of features = " . scalar(@features) . "\n";

    my @genes     = $contig->get_Genes_by_Type('pruned_TGW');

    print STDERR "Found " . scalar(@genes) . " genewise genes\n";

    my %redids;
    my $trancount = 1;

    foreach my $gene (@genes) {
      print STDERR "Found genewise gene " . $gene->id . "\n";
      foreach my $tran ($gene->each_Transcript) {
	foreach my $exon ($tran->each_Exon) {
	  print STDERR "Exon " . $exon->id . " " . $exon->strand . "\n";
	  my $strand = "+";
	  if ($exon->strand == -1) {
	    $strand = "-";
	  }

	  if ($exon->seqname eq $contig->id) {
	    print STDERR $exon->contig_id . "\tGD_CDS\tsexon\t" . $exon->start . "\t" . $exon->end . "\t100\t" . $strand .  "\t" . $exon->phase . "\t" . $tran->id . ".$trancount\n";
	    
	  FEAT: foreach my $f (@features) {
	      if ($exon->overlaps($f)) {
		$redids{$f->hseqname} = 1;
		print STDERR "ID " . $f->hseqname . " covered by genewise\n";
	    }
	    }
	  }
	}
	$trancount++;
      }
    }

    my %idhash;
    
    foreach my $f (@features) {
#        print "Feature " . $f . " " . $f->seqname . " " . $f->source_tag . "\n";
      if ($f->isa("Bio::EnsEMBL::FeaturePair") && 
	  defined($f->hseqname) &&
	    $redids{$f->hseqname} != 1) {
      $idhash{$f->hseqname} = 1;
      
    }
  }
    
    my @ids = keys %idhash;

    print STDERR "Feature ids are @ids\n";

    my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::BlastMiniGenewise('-genomic'  => $genseq,
									   '-ids'      => \@ids,
									   '-trim'     => 1);
    
    
    $self->add_Runnable($runnable);
    $self->{$runnable} = $contig;

}
     
sub add_Runnable {
    my ($self,$arg) = @_;

    if (!defined($self->{_runnables})) {
	$self->{_runnables} = [];
    }

    if (defined($arg)) {
	if ($arg->isa("Bio::EnsEMBL::Pipeline::RunnableI")) {
	    push(@{$self->{_runnables}},$arg);
	} else {
	    $self->throw("[$arg] is not a Bio::EnsEMBL::Pipeline::RunnableI");
	}
    }
}
sub get_Runnables {
    my ($self) = @_;

    if (!defined($self->{_runnables})) {
	$self->{_runnables} = [];
    }
    
    return @{$self->{_runnables}};
}

sub run {
    my ($self) = @_;

    foreach my $runnable ($self->get_Runnables) {
	$runnable->run;
    }
    
    $self->convert_output;

}

sub convert_output {
  my ($self) =@_;
  
  my $count = 1;
  my $time  = time; chomp($time);
  
  # This BAD! Shouldn't be using internal ids.
  # <sigh> no time to change it now
  my $analysis = $self->dbobj->get_OldAnalysis(7);
  my $trancount = 1;
  
  foreach my $runnable ($self->get_Runnables) {
    my $contig = $self->{$runnable};
    my @tmpf   = $runnable->output;
    
    my @genes;
    
    foreach my $tmpf (@tmpf) {
      
      my $gene   = new Bio::EnsEMBL::Gene;
      my $tran   = new Bio::EnsEMBL::Transcript;
      my $transl = new Bio::EnsEMBL::Translation;
      
      $gene->type('genewise');
      $gene->id($self->input_id . ".genewise.$count");
      $gene->created($time);
      $gene->modified($time);
      $gene->version(1);
      
      $tran->id($self->input_id . ".genewise.$count");
      $tran->created($time);
      $tran->modified($time);
      $tran->version(1);
      
      $transl->id($self->input_id . ".genewise.$count");
      $transl->version(1);
      
      $count++;
      
      $gene->add_Transcript($tran);
      $tran->translation($transl);
      
      
      my $excount = 1;
      my @exons;
      
      foreach my $subf ($tmpf->sub_SeqFeature) {
	$subf->feature1->source_tag('genewise');
	$subf->feature1->primary_tag('similarity');
	$subf->feature1->score(100);
	$subf->feature1->analysis($analysis);
	
	$subf->feature2->source_tag('genewise');
	$subf->feature2->primary_tag('similarity');
	$subf->feature2->score(100);
	$subf->feature2->analysis($analysis);

	my $exon = new Bio::EnsEMBL::Exon;
	
	$exon->id($self->input_id . ".genewise.$count.$excount");
	$exon->contig_id($contig->id);
	$exon->created($time);
	$exon->modified($time);
	$exon->version(1);
	
	$exon->start($subf->start);
	$exon->end  ($subf->end);
	$exon->strand($subf->strand);
	
	print STDERR "\tFeaturePair " . $subf->gffstring . "\n";
	
	$exon->phase($subf->feature1->{_phase});
	$exon->attach_seq($self->{$runnable}->primary_seq);
	$exon->add_Supporting_Feature($subf);
	
	my $seq   = new Bio::Seq(-seq => $exon->seq->seq);
	
	my $tran0 =  $seq->translate('*','X',0)->seq;
	my $tran1 =  $seq->translate('*','X',2)->seq;
	my $tran2 =  $seq->translate('*','X',1)->seq;
	
	print STDERR "\n\t exon phase 0 : " . $tran0 . " " . $exon->phase . "\n";
	print STDERR "\t exon phase 1 : " . $tran1 . "\n";
	print STDERR "\t exon phase 2 : " . $tran2 . "\n";
	
	push(@exons,$exon);
	
	$excount++;
      }
      
      if ($#exons < 0) {
	print STDERR "Odd.  No exons found\n";
      } else {
	
	push(@genes,$gene);
	
	if ($exons[0]->strand == -1) {
	  @exons = sort {$b->start <=> $a->start} @exons;
	} else {
	  @exons = sort {$a->start <=> $b->start} @exons;
	}
	
	foreach my $exon (@exons) {
	  $tran->add_Exon($exon);
	}
	
	$transl->start_exon_id($exons[0]->id);
	$transl->end_exon_id  ($exons[$#exons]->id);
	
	if ($exons[0]->phase == 0) {
	  $transl->start(1);
	} elsif ($exons[0]->phase == 1) {
	  $transl->start(3);
	} elsif ($exons[0]->phase == 2) {
	  $transl->start(2);
	}
	
	$transl->end  ($exons[$#exons]->end - $exons[$#exons]->start + 1);
      }
    }

  my @newf;
  foreach my $gene (@genes) {
    foreach my $tran ($gene->each_Transcript) {
      print STDERR " Translation is " . $tran->translate->seq . "\n";
      foreach my $exon ($tran->each_Exon) {
	my $strand = "+";
	if ($exon->strand == -1) {
	  $strand = "-";
	}
	print STDERR $exon->contig_id . "\tgenewise\tsexon\t" . $exon->start . "\t" . $exon->end . "\t100\t" . $strand .  "\t" . $exon->phase . "\t" . $tran->id . ".$trancount\n";
      }
      $trancount++;
    }
    
    eval {
      my $newgene = $contig->convert_Gene_to_raw_contig($gene);
      $newgene->type('genewise');
      push(@newf,$newgene);
    };
    if ($@) {
      print STDERR "Couldn't reverse map gene " . $gene->id . " [$@]\n";
    }
    
    if (!defined($self->{_output})) {
      $self->{_output} = [];
    }
    
    push(@{$self->{_output}},@newf);
  }
}
}

sub check_splice {
    my ($self,$f1,$f2) = @_;
    
    my $splice1 = substr($self->{_genseq}->seq,$f1->end,2);
    my $splice2 = substr($self->{_genseq}->seq,$f2->start-3,2);
    
    if (abs($f2->start - $f1->end) > 50) {
	print ("Splices are " . $f1->hseqname . " [" . 
	                        $splice1      . "][" . 
	                        $splice2      . "] " . 
	       ($f2->start - $f1->end)        . "\n");
    }
}


sub output {
    my ($self) = @_;
   
    if (!defined($self->{_output})) {
      $self->{_output} = [];
    } 
    return @{$self->{_output}};
}


1;


