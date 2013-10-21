//BFS using vertexAPI2

#include "util.h"
#include "graphio.h"
#include "refgas.h"
#include "gpugas.h"


//nvcc doesn't like the __device__ variable to be a static member inside BFS
//so these are both outside.
int g_iterationCount;
__device__ __constant__ int g_iterationCountGPU;


struct BFS
{
  struct VertexData
  {
    int depth;
  };

  struct EdgeData {}; //nothing

  typedef int GatherResult;
  static const int gatherZero = INT_MAX - 1;

  __host__ __device__
  static int gatherReduce(const int& left, const int& right)
  {
    return 0; //do nothing
  }


  __host__ __device__
  static int gatherMap(const VertexData* dst, const VertexData *src, const EdgeData* edge)
  {
    return 0; //do nothing
  }


  __host__ __device__
  static bool apply(VertexData* vert, int dist)
  {
    if( vert->depth == -1 )
    {
      #ifdef __CUDA_ARCH__
        vert->depth = g_iterationCountGPU;
      #else
        vert->depth = g_iterationCount;
      #endif        
      return true;
    }
    return false;
  }


  __host__ __device__
  static void scatter(const VertexData* src, const VertexData *dst, EdgeData* edge)
  {
    //nothing
  }
};


//struct BFSHost : public BFSBase
//{
//  static bool apply(VertexData* vert, int dist)
//  {
//    if( vert->depth == -1 )
//    {
//      vert->depth = g_iterationCount;
//      return true;
//    }
//    return false;
//  }
//};
//
//
//struct BFSDev : public BFSBase
//{
//  __device__
//  static bool apply(VertexData* vert, int dist)
//  {
//    if( vert->depth == -1 )
//    {
//      vert->depth = g_iterationCountGPU;
//      return true;
//    }
//    return false;
//  }
//};


int main(int argc, char** argv)
{
  char *inputFilename;
  int sourceVertex;
  if( !parseCmdLineSimple(argc, argv, "si", &inputFilename, &sourceVertex) )
    exit(1);

  //load the graph
  int nVertices;
  std::vector<int> srcs;
  std::vector<int> dsts;
  loadGraph(inputFilename, nVertices, srcs, dsts);

  //run on host
  {
    //initialize vertex data
    std::vector<BFS::VertexData> vertexData(nVertices);
    for( int i = 0; i < nVertices; ++i )
      vertexData[i].depth = -1; 

    GASEngineRef<BFS> engine;
    engine.setGraph(nVertices, &vertexData[0], srcs.size(), 0, &srcs[0], &dsts[0]);
    engine.setActive(sourceVertex, sourceVertex+1);
    g_iterationCount = 0;
    while( engine.countActive() )
    {
      //run apply without gather
      engine.gatherApply(false);
      engine.scatterActivate(false);
      engine.nextIter();
      ++g_iterationCount;
    }
    engine.getResults();

    //output distances;
    for( int i = 0; i < nVertices; ++i )
      printf("%d %d\n", i, vertexData[i].depth);
  }


  //run on gpu
  {
    //initialize vertex data
    std::vector<BFS::VertexData> vertexData(nVertices);
    for( int i = 0; i < nVertices; ++i )
      vertexData[i].depth = -1; 

    GASEngineGPU<BFS> engine;
    engine.setGraph(nVertices, &vertexData[0], srcs.size(), 0, &srcs[0], &dsts[0]);
    engine.setActive(sourceVertex, sourceVertex+1);
    int iter = 0;
    cudaMemcpyToSymbol(g_iterationCountGPU, &iter, sizeof(iter));
    while( engine.countActive() )
    {
      //run apply without gather
      engine.gatherApply(false);
      engine.scatterActivate(false);
      engine.nextIter();
      ++iter;
      cudaMemcpyToSymbol(g_iterationCountGPU, &iter, sizeof(iter));
    }
    engine.getResults();

    //output distances;
    for( int i = 0; i < nVertices; ++i )
      printf("%d %d\n", i, vertexData[i].depth);
  }



    
}
